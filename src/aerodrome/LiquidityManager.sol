// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Interfaces
import {ICLFactory} from "./v3-core/contracts/interfaces/ICLFactory.sol";
import {ICLMintCallback} from "./v3-core/contracts/interfaces/callback/ICLMintCallback.sol";
import {ICLPool} from "./v3-core/contracts/interfaces/ICLPool.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// Libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {PoolAddress} from "./v3-periphery/libraries/PoolAddress.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Aerodrome
abstract contract LiquidityManager is ICLMintCallback {
    // NOTE: THE FACTORY IS DEPLOYER IN THIS CASE
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    /// @inheritdoc ICLMintCallback
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        verifyCallback(factory, decoded.poolKey);

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
        address recipient;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Add liquidity to an initialized pool
    function addLiquidity(AddLiquidityParams memory params)
        public
        returns (uint128 liquidity, uint256 amount0, uint256 amount1, ICLPool pool)
    {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.PoolKey({token0: params.token0, token1: params.token1, tickSpacing: params.tickSpacing});

        pool = ICLPool(computeAddress(factory, poolKey));

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
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(address token, address payer, address recipient, uint256 value) internal {
        // pull payment
        if (payer == address(this)) {
            SafeERC20.safeTransfer(IERC20(token), recipient, value);
        } else {
            SafeERC20.safeTransferFrom(IERC20(token), payer, recipient, value);
        }
    }

    function getPoolKey(address tokenA, address tokenB, int24 tickSpacing)
        internal
        pure
        returns (PoolAddress.PoolKey memory)
    {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolAddress.PoolKey({token0: tokenA, token1: tokenB, tickSpacing: tickSpacing});
    }

    function computeAddress(address _factory, PoolAddress.PoolKey memory key) internal view returns (address pool) {
        return PoolAddress.computeAddress(_factory, key);
    }

    function verifyCallback(address _factory, address tokenA, address tokenB, int24 tickSpacing)
        internal
        view
        returns (ICLPool pool)
    {
        return verifyCallback(_factory, PoolAddress.getPoolKey(tokenA, tokenB, tickSpacing));
    }

    function verifyCallback(address _factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (ICLPool pool)
    {
        pool = ICLPool(computeAddress(_factory, poolKey));
        require(msg.sender == address(pool));
    }
}
