// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IFusionXV3Factory} from "../src/fusionX-v3/v3-core/contracts/interfaces/IFusionXV3Factory.sol";
import {IFusionXV3Pool} from "../src/fusionX-v3/v3-core/contracts/interfaces/IFusionXV3Pool.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {ISwapRouter} from "v3-periphery/SwapRouter.sol";
import {SqrtPriceMath} from "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {SwapMath} from "@uniswap/v3-core/contracts/libraries/SwapMath.sol";

import {FusionXV3LiquidityManagement} from "./fusionX-v3-utils/FusionXV3LiquidityManagement.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract FusionXV3Test is Test {
    ERC20Mock token0; // LUSD
    ERC20Mock token1; // ETH
    IFusionXV3Factory factory;
    IFusionXV3Pool pool;
    uint24 fee;
    FusionXV3LiquidityManagement fusionXV3LiquidityManagement;
    ISwapRouter swapRouter;
    address public user = address(0x6969);
    /**
     * price = 2000 LUSD
     *     invPrice = 1 / 2000
     *     sqrtPriceX96 = sqrt(invPrice) * 2**96
     */
    // uint160 initSqrtPriceX96 = 1771595571142957112070504448; // 1 ETH = 2000 LUSD
    uint160 initSqrtPriceX96 = 1771845812700903892492222464; // 1 ETH = 2000 LUSD

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();
        if (address(token0) >= address(token1)) {
            (token0, token1) = (token1, token0);
        }

        factory = IFusionXV3Factory(0x530d2766D1988CC1c000C8b7d00334c14B69AD71);

        fee = 500;

        pool = IFusionXV3Pool(factory.createPool(address(token0), address(token1), fee));

        pool.initialize(initSqrtPriceX96);

        fusionXV3LiquidityManagement = new FusionXV3LiquidityManagement(0x8790c2C3BA67223D83C8FCF2a5E3C650059987b4);

        swapRouter = ISwapRouter(0x5989FB161568b9F133eDf5Cf6787f5597762797F);
    }

    function testPoolDeployment() public view {
        (uint160 sqrtPriceX96, int24 tick,,,,, bool unlocked) = pool.slot0();
        assert(sqrtPriceX96 == initSqrtPriceX96);
        assert(tick == TickMath.getTickAtSqrtRatio(initSqrtPriceX96));
        assert(unlocked == true);
    }

    function testAddingLiquidity() public {
        int24 tickLower = (-78245 / int24(10)) * 10 + 10;
        int24 tickUpper = (-73136 / int24(10)) * 10;
        uint160 lower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 upper = TickMath.getSqrtRatioAtTick(tickUpper);
        uint256 liquidity0 = LiquidityAmounts.getLiquidityForAmount0(lower, upper, 500000e18);
        uint256 liquidity1 = LiquidityAmounts.getLiquidityForAmount1(lower, upper, 250e18);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            initSqrtPriceX96, lower, upper, uint128(liquidity0 < liquidity1 ? liquidity0 : liquidity1)
        );
        vm.startPrank(user);
        token0.mint(user, 500000e18);
        token1.mint(user, 250e18);
        token0.approve(address(fusionXV3LiquidityManagement), type(uint256).max);
        token1.approve(address(fusionXV3LiquidityManagement), type(uint256).max);
        (uint128 liquidity,,,) = fusionXV3LiquidityManagement.addLiquidity(
            FusionXV3LiquidityManagement.AddLiquidityParams({
                token0: pool.token0(),
                token1: pool.token1(),
                fee: fee,
                recipient: user,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        (uint128 selfLiquidity,,,,) = pool.positions(keccak256(abi.encodePacked(user, tickLower, tickUpper)));
        assert(selfLiquidity == liquidity);
        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        testAddingLiquidity();
        int24 tickLower = (-78245 / int24(10)) * 10 + 10;
        int24 tickUpper = (-73136 / int24(10)) * 10;
        (uint128 selfLiquidity,,,,) = pool.positions(keccak256(abi.encodePacked(user, tickLower, tickUpper)));
        vm.startPrank(user);
        (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            initSqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            selfLiquidity
        );
        (uint256 amount0, uint256 amount1) = pool.burn(tickLower, tickUpper, selfLiquidity);
        pool.collect(user, tickLower, tickUpper, uint128(amount0), uint128(amount1));
        vm.stopPrank();
        (uint128 selfLiquidityAfter,,,,) = pool.positions(keccak256(abi.encodePacked(user, tickLower, tickUpper)));
        assert(selfLiquidityAfter == 0);
        assert(expectedAmount0 == amount0);
        assert(expectedAmount1 == amount1);
    }

    function testSwapping() public {
        testAddingLiquidity();
        uint256 amountIn = 10000e18;
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint128 liquidity = pool.liquidity();
        uint160 sqrtPriceX96Next = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtPriceX96, liquidity, amountIn, true);
        int24 newTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96Next);
        (uint160 sqrtRatioNextX96A,, uint256 amountOut,) =
            SwapMath.computeSwapStep(sqrtPriceX96, sqrtPriceX96Next, liquidity, int256(amountIn), fee);
        vm.startPrank(user);
        token1.transfer(address(0xdead), token1.balanceOf(user));
        token0.mint(user, amountIn);
        token0.approve(address(swapRouter), type(uint256).max);
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: pool.token0(),
                tokenOut: pool.token1(),
                fee: fee,
                recipient: user,
                deadline: block.timestamp + 5 days,
                amountIn: amountIn,
                amountOutMinimum: amountOut,
                sqrtPriceLimitX96: 0
            })
        );
        (uint160 sqrtPriceX96Latest, int24 tickLatest,,,,,) = pool.slot0();
        assert(sqrtPriceX96Latest == sqrtRatioNextX96A);
        assert(newTick == tickLatest);
        assert(token1.balanceOf(user) == amountOut);
        vm.stopPrank();
    }

    function testReachAParticularPrice() public {
        testAddingLiquidity();
        // assume uniform liquidity at each tick
        uint160 targetSqrtPriceX96 = 1585832424097319824641753088; // 1 ETH = 2200 LUSD
        console.log("Target: ", targetSqrtPriceX96);
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();
        console.log("Current: ", sqrtPriceX96);
        // for (int24 i = 73136; i <= 78245; i++) {
        //     (
        //         uint128 liquidityGross,
        //         int128 liquidityNet,
        //         ,
        //         ,
        //         ,
        //         ,
        //         ,
        //         bool initialized
        //     ) = pool.ticks(-(i));
        //     if (initialized == true) {
        //         console.log(liquidityGross);
        //         console.logInt(liquidityNet);
        //         console.log(TickMath.getSqrtRatioAtTick(-(i)));
        //         console.logInt(-(i));
        //     }
        // }
        // uint256 amountIn = 0;
        // int24 tickLower = (tick / int24(10)) * 10 + 10;
        uint128 liquidity = pool.liquidity();
        uint256 amountIn = SqrtPriceMath.getAmount0Delta(sqrtPriceX96, targetSqrtPriceX96, liquidity, true);
        uint160 sqrtPriceX96Next = SqrtPriceMath.getNextSqrtPriceFromInput(sqrtPriceX96, liquidity, amountIn, true);
        int24 newTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96Next);
        (uint160 sqrtRatioNextX96A,, uint256 amountOut,) =
            SwapMath.computeSwapStep(sqrtPriceX96, sqrtPriceX96Next, liquidity, int256(amountIn), fee);
        vm.startPrank(user);
        token1.transfer(address(0xdead), token1.balanceOf(user));
        token0.mint(user, amountIn);
        token0.approve(address(swapRouter), type(uint256).max);
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: pool.token0(),
                tokenOut: pool.token1(),
                fee: fee,
                recipient: user,
                deadline: block.timestamp + 5 days,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        (uint160 sqrtPriceX96Latest, int24 tickLatest,,,,,) = pool.slot0();
        console.log(sqrtPriceX96Latest);
        // assert(sqrtPriceX96Latest == sqrtRatioNextX96A);
        // assert(newTick == tickLatest);
        // assert(token1.balanceOf(user) == amountOut);
        (uint128 liquidityGross, int128 liquidityNet,,,,,, bool initialized) = pool.ticks(-78230);
        vm.stopPrank();
    }
}
