// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IFusionXV3Factory} from "../../../src/fusionX-v3/v3-core/contracts/interfaces/IFusionXV3Factory.sol";
import {IFusionXV3Pool} from "../../../src/fusionX-v3/v3-core/contracts/interfaces/IFusionXV3Pool.sol";
import {IFusionXV3MintCallback} from
    "../../../src/fusionX-v3/v3-core/contracts/interfaces/callback/IFusionXV3MintCallback.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "../../../src/fusionX-v3/v3-periphery/libraries/PoolAddress.sol";
import "../../../src/fusionX-v3/v3-periphery/libraries/CallbackValidation.sol";
import "v3-periphery/libraries/LiquidityAmounts.sol";

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in FusionX V3
contract FusionXV3LiquidityManagement is IFusionXV3MintCallback {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    /// @inheritdoc IFusionXV3MintCallback
    function fusionXV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount0Owed > 0) {
            pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
        }
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        uint24 fee;
        address recipient;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Add liquidity to an initialized pool
    function addLiquidity(AddLiquidityParams memory params)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1, IFusionXV3Pool pool)
    {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});

        pool = IFusionXV3Pool(PoolAddress.computeAddress(factory, poolKey));

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, params.amount0Desired, params.amount1Desired
            );
        }

        (amount0, amount1) = pool.mint(
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "Price slippage check");
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(address token, address payer, address recipient, uint256 value) internal {
        // pull payment
        SafeERC20.safeTransferFrom(IERC20(token), payer, recipient, value);
    }
}
