// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../../../src/aerodrome/v3-core/contracts/interfaces/ICLFactory.sol";
import "../../../src/aerodrome/v3-core/contracts/interfaces/callback/ICLMintCallback.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "../../../src/aerodrome/v3-periphery/libraries/PoolAddress.sol";
import "../../../src/aerodrome/v3-periphery/libraries/CallbackValidation.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in CL
contract AerodromeLiquidityManagement is ICLMintCallback {
    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    struct AddLiquidityParams {
        address poolAddress;
        PoolAddress.PoolKey poolKey;
        address recipient;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    /// @inheritdoc ICLMintCallback
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
    }

    /// @notice Add liquidity to an initialized pool
    function addLiquidity(AddLiquidityParams memory params)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        ICLPool pool = ICLPool(params.poolAddress);

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96,,,,,) = pool.slot0();
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
            abi.encode(MintCallbackData({poolKey: params.poolKey, payer: msg.sender}))
        );

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "PSC"); // price slippage check
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
