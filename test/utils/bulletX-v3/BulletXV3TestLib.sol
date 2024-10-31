// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IBulletXV3Pool} from "../../src/bulletX-v3/v3-core/contracts/interfaces/IBulletXV3Pool.sol";
import {IBulletXV3Factory} from "../../src/bulletX-v3/v3-core/contracts/interfaces/IBulletXV3Factory.sol";
import {SwapRouter, ISwapRouter} from "v3-periphery/SwapRouter.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {ISwapRouter} from "v3-periphery/SwapRouter.sol";
import {SqrtPriceMath} from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {SwapMath} from "@uniswap/v3-core/contracts/libraries/SwapMath.sol";

import {BulletXV3LiquidityManagement} from "./BulletXV3LiquidityManagement.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract BulletXV3TestLib is Test {
    IBulletXV3Factory public immutable factory;
    BulletXV3LiquidityManagement public immutable bulletXV3LiquidityManagement;
    ISwapRouter public immutable swapRouter;

    struct AddLiquidityStruct {
        address user;
        IBulletXV3Pool pool;
        int24 desiredTickLower;
        int24 desiredTickUpper;
        uint256 desiredAmount0;
        uint256 desiredAmount1;
        bool requireMint;
    }

    struct RemoveLiquidityStruct {
        address user;
        IBulletXV3Pool pool;
        int24 desiredTickLower;
        int24 desiredTickUpper;
        uint128 liquidity;
        bool collectFees;
    }

    struct SwapParamsStruct {
        address user;
        IBulletXV3Pool pool;
        uint256 amountIn;
        bool zeroForOne;
        bool requireMint;
    }

    struct TeleportParamsStruct {
        address user;
        IBulletXV3Pool pool;
        uint160 targetSqrtPriceX96;
        bool zeroForOne;
    }

    constructor() {
        factory = IBulletXV3Factory(0x530d2766D1988CC1c000C8b7d00334c14B69AD71);

        bulletXV3LiquidityManagement = new BulletXV3LiquidityManagement(0x8790c2C3BA67223D83C8FCF2a5E3C650059987b4);

        swapRouter = ISwapRouter(0x5989FB161568b9F133eDf5Cf6787f5597762797F);
    }

    function deployBulletXV3PoolAndInitializePrice(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        public
        returns (address pool)
    {
        if (token0 >= token1) {
            (token0, token1) = (token1, token0);
        }

        pool = factory.createPool(token0, token1, fee);

        IBulletXV3Pool(pool).initialize(sqrtPriceX96);
    }

    function getCurrentSqrtPriceX96(IBulletXV3Pool pool) public view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = pool.slot0();
    }

    function getCurrentTick(IBulletXV3Pool pool) public view returns (int24 tick) {
        (, tick,,,,,) = pool.slot0();
    }

    function addLiquidity(AddLiquidityStruct memory _params) public returns (uint128 liquidity) {
        ERC20Mock token0 = ERC20Mock(_params.pool.token0());
        ERC20Mock token1 = ERC20Mock(_params.pool.token1());

        uint160 lower = TickMath.getSqrtRatioAtTick((_params.desiredTickLower / int24(10)) * 10 + 10);
        uint160 upper = TickMath.getSqrtRatioAtTick((_params.desiredTickUpper / int24(10)) * 10);

        uint256 liquidity0;
        uint256 liquidity1;
        uint256 amount0;
        uint256 amount1;

        {
            if (_params.desiredAmount0 > 0 && _params.desiredAmount1 > 0) {
                liquidity0 = LiquidityAmounts.getLiquidityForAmount0(lower, upper, _params.desiredAmount0);

                liquidity1 = LiquidityAmounts.getLiquidityForAmount1(lower, upper, _params.desiredAmount1);

                (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                    getCurrentSqrtPriceX96(_params.pool),
                    lower,
                    upper,
                    uint128(liquidity0 < liquidity1 ? liquidity0 : liquidity1)
                );
            } else if (_params.desiredAmount0 > 0) {
                liquidity0 = LiquidityAmounts.getLiquidityForAmount0(lower, upper, _params.desiredAmount0);

                (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                    getCurrentSqrtPriceX96(_params.pool), lower, upper, uint128(liquidity0)
                );
            } else {
                liquidity1 = LiquidityAmounts.getLiquidityForAmount1(lower, upper, _params.desiredAmount1);

                (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                    getCurrentSqrtPriceX96(_params.pool), lower, upper, uint128(liquidity1)
                );
            }
        }

        if (_params.requireMint) {
            if (amount0 > 0) token0.mint(_params.user, amount0);
            if (amount1 > 0) token1.mint(_params.user, amount1);
        }

        vm.startPrank(_params.user);

        token0.approve(address(bulletXV3LiquidityManagement), type(uint256).max);
        token1.approve(address(bulletXV3LiquidityManagement), type(uint256).max);

        (liquidity,,,) = bulletXV3LiquidityManagement.addLiquidity(
            BulletXV3LiquidityManagement.AddLiquidityParams({
                token0: _params.pool.token0(),
                token1: _params.pool.token1(),
                fee: _params.pool.fee(),
                recipient: _params.user,
                tickLower: (_params.desiredTickLower / int24(10)) * 10 + 10,
                tickUpper: (_params.desiredTickUpper / int24(10)) * 10,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0
            })
        );

        vm.stopPrank();
    }

    function removeLiquidity(RemoveLiquidityStruct memory _params) public returns (uint256 amount0, uint256 amount1) {
        int24 tickLower = (_params.desiredTickLower / int24(10)) * 10 + 10;
        int24 tickUpper = (_params.desiredTickUpper / int24(10)) * 10;

        if (_params.liquidity <= 0) {
            (_params.liquidity,,,,) =
                _params.pool.positions(keccak256(abi.encodePacked(_params.user, tickLower, tickUpper)));
        }

        vm.startPrank(_params.user);

        // (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts
        //     .getAmountsForLiquidity(
        //         getCurrentSqrtPriceX96(_params.pool),
        //         TickMath.getSqrtRatioAtTick(tickLower),
        //         TickMath.getSqrtRatioAtTick(tickUpper),
        //         _params.liquidity
        //     );

        (amount0, amount1) = _params.pool.burn(tickLower, tickUpper, _params.liquidity);

        if (_params.collectFees) {
            _params.pool.collect(_params.user, tickLower, tickUpper, uint128(amount0), uint128(amount1));
        }

        vm.stopPrank();
    }

    function performSwap(SwapParamsStruct memory _params) public returns (uint256 amountOut) {
        ERC20Mock token0 = ERC20Mock(_params.pool.token0());
        ERC20Mock token1 = ERC20Mock(_params.pool.token1());

        vm.startPrank(_params.user);
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        if (_params.requireMint) {
            if (_params.zeroForOne) {
                token0.mint(_params.user, _params.amountIn);
            } else {
                token1.mint(_params.user, _params.amountIn);
            }
        }

        (amountOut) = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _params.zeroForOne ? _params.pool.token0() : _params.pool.token1(),
                tokenOut: _params.zeroForOne ? _params.pool.token1() : _params.pool.token0(),
                fee: _params.pool.fee(),
                recipient: _params.user,
                deadline: block.timestamp + 5 days,
                amountIn: _params.amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function teleportToPrice(TeleportParamsStruct memory _params)
        public
        returns (uint256 amountIn, uint256 amountOut, uint160 latestSqrtPriceX96)
    {
        ERC20Mock token0 = ERC20Mock(_params.pool.token0());
        ERC20Mock token1 = ERC20Mock(_params.pool.token1());

        uint128 liquidity = _params.pool.liquidity();
        uint160 sqrtPriceX96 = getCurrentSqrtPriceX96(_params.pool);

        amountIn = SqrtPriceMath.getAmount0Delta(sqrtPriceX96, _params.targetSqrtPriceX96, liquidity, true);

        vm.startPrank(_params.user);

        if (_params.zeroForOne) {
            token0.mint(_params.user, amountIn);
            token0.approve(address(swapRouter), type(uint256).max);
        } else {
            token1.mint(_params.user, amountIn);
            token1.approve(address(swapRouter), type(uint256).max);
        }

        (amountOut) = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _params.zeroForOne ? _params.pool.token0() : _params.pool.token1(),
                tokenOut: _params.zeroForOne ? _params.pool.token1() : _params.pool.token0(),
                fee: _params.pool.fee(),
                recipient: _params.user,
                deadline: block.timestamp + 5 days,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        vm.stopPrank();

        latestSqrtPriceX96 = getCurrentSqrtPriceX96(_params.pool);
    }
}
