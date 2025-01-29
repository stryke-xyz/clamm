// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {DopexV2PositionManagerV2} from "../../src/DopexV2PositionManagerV2.sol";
import {IHandlerV3} from "../../src/interfaces/IHandlerV3.sol";
import {SushiV3TestLib} from "../utils/sushi-v3/SushiV3TestLib.sol";
import {SushiV3SingleTickLiquidityHarnessV3} from "../harness/SushiV3SingleTickLiquidityHarnessV3.sol";
import {SushiV3SingleTickLiquidityHandlerV3} from "../../src/handlers/SushiV3SingleTickLiquidityHandlerV3.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

contract SushiV3SingleTickLiquidityHandlerV3_Test is Test {
    using TickMath for int24;

    address ETH; // token1
    address LUSD; // token0

    ERC20Mock token0;
    ERC20Mock token1;

    SushiV3TestLib testLib;
    IUniswapV3Pool pool;

    uint24 fee = 500;

    uint160 initSqrtPriceX96 = 1771845812700903892492222464; // 1 ETH = 2000 LUSD

    address alice = makeAddr("alice"); // main LP
    address bob = makeAddr("bob"); // protocol LP
    address jason = makeAddr("jason"); // protocol LP
    address trader = makeAddr("trader"); // option buyer
    address garbage = makeAddr("garbage"); // garbage address
    address roger = makeAddr("roger"); // roger address
    address tango = makeAddr("tango"); // tango address

    DopexV2PositionManagerV2 positionManager;
    SushiV3SingleTickLiquidityHarnessV3 positionManagerHarness;
    SushiV3SingleTickLiquidityHandlerV3 handler;

    address hook = address(0);
    bytes hookData = new bytes(0);

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 218294000);

        ETH = address(new ERC20Mock());
        LUSD = address(new ERC20Mock());

        testLib = new SushiV3TestLib();
        pool = IUniswapV3Pool(testLib.deploySushiV3PoolAndInitializePrice(ETH, LUSD, fee, initSqrtPriceX96));

        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        testLib.addLiquidity(
            SushiV3TestLib.AddLiquidityStruct({
                user: alice,
                pool: pool,
                desiredTickLower: -78245, // 2500
                desiredTickUpper: -73136, // 1500
                desiredAmount0: 5_000_000e18,
                desiredAmount1: 0,
                requireMint: true
            })
        );

        positionManager = new DopexV2PositionManagerV2();

        handler = new SushiV3SingleTickLiquidityHandlerV3(
            0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e,
            0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54,
            address(testLib.swapRouter())
        );

        handler.updateWhitelistedPools(address(pool), true);

        positionManagerHarness = new SushiV3SingleTickLiquidityHarnessV3(testLib, positionManager, handler);

        positionManager.updateWhitelistHandlerWithApp(address(handler), garbage, true);

        positionManager.updateWhitelistHandler(address(handler), true);

        handler.updateWhitelistedApps(address(positionManager), true);

        handler.updateWhitelistedPools(address(pool), true);
    }

    function testMintPosition() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -77420; // 2299.8
        int24 tickUpper = -77410; // 2302.1

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);
    }

    function testMintPositionWithOneSwap() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        uint256 amount01 = 10_000e18;
        uint256 amount11 = 0;

        int24 tickLower = -77420; // 2299.8
        int24 tickUpper = -77410; // 2302.1

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, amount01, amount11, tickLower, tickUpper, pool, hook, jason);
    }

    function testMintPositionWithOneSwap2() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        uint256 amount01 = 10_000e18;
        uint256 amount11 = 0;

        int24 tickLower = -77420; // 2299.8
        int24 tickUpper = -77410; // 2302.1

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, amount01, amount11, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);
    }

    function testMintPositionWithSwaps() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -77420; // 2299.8
        int24 tickUpper = -77410; // 2302.1

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );
    }

    function testBurnPosition() public {
        int24 tickLower = -77420;
        int24 tickUpper = -77410;

        testMintPositionWithSwaps();

        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.burnPosition(
            jasonBalance - 1, // since you can't reset the shares
            tickLower,
            tickUpper,
            pool,
            hook,
            jason
        );
    }

    function testBurnPositionSmallValue() public {
        int24 tickLower = -77420;
        int24 tickUpper = -77410;

        positionManagerHarness.mintPosition(token0, token1, 0, 2, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, 2, 0, tickLower, tickUpper, pool, hook, jason);

        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.burnPosition(
            jasonBalance - 1, // since you can't reset the shares
            tickLower,
            tickUpper,
            pool,
            hook,
            jason
        );
    }

    function testUsePosition() public {
        testMintPositionWithSwaps();
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -77420;
        int24 tickUpper = -77410;

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );
    }

    function testUnusePosition() public {
        testMintPosition();
        testUsePosition();

        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -77420;
        int24 tickUpper = -77410;

        positionManagerHarness.unusePosition(
            amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.burnPosition(
            jasonBalance - 1, // since you can't reset the shares
            tickLower,
            tickUpper,
            pool,
            hook,
            jason
        );
    }

    function testDonation() public {
        testMintPosition();

        uint256 amount0 = 0;
        uint256 amount1 = 0;

        int24 tickLower = -77420;
        int24 tickUpper = -77410;

        vm.roll(block.number + 1);

        positionManagerHarness.donatePosition(
            token0, token1, amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, garbage
        );

        vm.roll(block.number + 5);

        positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, roger);

        positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, tango);

        vm.roll(block.number + 10);

        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        uint256 rogerBalance =
            handler.balanceOf(roger, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        uint256 tangoBalance =
            handler.balanceOf(tango, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.burnPosition(jasonBalance, tickLower, tickUpper, pool, hook, jason);
        positionManagerHarness.burnPosition(rogerBalance, tickLower, tickUpper, pool, hook, roger);
        positionManagerHarness.burnPosition(
            tangoBalance - 1, // since you can't reset the shares
            tickLower,
            tickUpper,
            pool,
            hook,
            tango
        );
    }

    function testPutOptionSim() public {
        uint256 amount0 = 10_000e18;
        uint256 amount1 = 0;

        int24 tickLower = -75770; // ~1950
        int24 tickUpper = -75760; // ~1952

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        SushiV3SingleTickLiquidityHandlerV3.TokenIdInfo memory tki =
            handler.getTokenIdData(uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper))));

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: trader,
                pool: pool,
                amountIn: 200e18, // pushes to 1921
                zeroForOne: false,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token0.balanceOf(garbage), // pushes to 1925
                zeroForOne: true,
                requireMint: false
            })
        );

        (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
            testLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            tki.liquidityUsed
        );

        positionManagerHarness.unusePosition(a0, a1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token1.balanceOf(garbage), // pushes to 1921
                zeroForOne: false,
                requireMint: false
            })
        );

        // console.log("Profit: ", token0.balanceOf(garbage));
    }

    function testCallOptionSim() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        SushiV3SingleTickLiquidityHandlerV3.TokenIdInfo memory tki =
            handler.getTokenIdData(uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper))));

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: trader,
                pool: pool,
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token1.balanceOf(garbage), // pushes to 2076
                zeroForOne: false,
                requireMint: false
            })
        );

        (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
            testLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            tki.liquidityUsed
        );

        positionManagerHarness.unusePosition(a0, a1, 1, 0, tickLower, tickUpper, pool, hook, hookData, garbage);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token0.balanceOf(garbage), // pushes to 1921
                zeroForOne: true,
                requireMint: false
            })
        );
    }

    function testReserveLiquidity() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        bytes memory reserveData = abi.encode(
            SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                pool: pool,
                hook: hook,
                tickLower: tickLower,
                tickUpper: tickUpper,
                shares: uint128(bobBalance)
            })
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        vm.warp(block.timestamp + 6 hours);
        vm.startPrank(bob);

        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        reserveData = abi.encode(
            SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                pool: pool,
                hook: hook,
                tickLower: tickLower,
                tickUpper: tickUpper,
                shares: uint128(bobReserveBalance)
            })
        );

        positionManager.withdrawReserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    function testReserveLiquidityWithSwaps() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        bytes memory reserveData = abi.encode(
            SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                pool: pool,
                hook: hook,
                tickLower: tickLower,
                tickUpper: tickUpper,
                shares: uint128(bobBalance)
            })
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        positionManagerHarness.unusePosition(
            amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            SushiV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        vm.warp(block.timestamp + 6 hours);
        vm.startPrank(bob);

        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        reserveData = (
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );

        positionManager.withdrawReserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    function testWithdrawWithoutLiquidityUsed() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        vm.startPrank(bob);
        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        bytes memory reserveData = (
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        vm.warp(block.timestamp + 6 hours);
        vm.startPrank(bob);
        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        reserveData = (
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    function testFail_WithdrawReserveBeforeCooldown() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        bytes memory reserveData = abi.encode(
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        vm.startPrank(bob);
        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        reserveData = (
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();
    }

    function testFail_WithdrawingReserveLiquidity() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        positionManagerHarness.usePosition(amount0, amount1 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        bytes memory reserveData = (
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    function testFail_UsingReservedLiqudiity() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76260; // ~2050
        int24 tickUpper = -76250; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        bytes memory reserveData = (
            abi.encode(
                SushiV3SingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );

        positionManager.reserveLiquidity(IHandlerV3(address(handler)), reserveData);

        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        positionManagerHarness.usePosition(amount0, amount1 / 2, tickLower, tickUpper, pool, hook, hookData, garbage);
    }
}
