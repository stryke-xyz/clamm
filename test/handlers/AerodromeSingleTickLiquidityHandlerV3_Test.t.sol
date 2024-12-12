// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {ICLFactory} from "../../src/aerodrome/v3-core/contracts/interfaces/ICLFactory.sol";
import {ICLPool} from "../../src/aerodrome/v3-core/contracts/interfaces/ICLPool.sol";
import {ISwapRouter} from "../../src/aerodrome/v3-core/contracts/interfaces/ISwapRouter.sol";

import {AerodromeTestLib} from "../utils/aerodrome/AerodromeTestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {AerodromeSingleTickLiquidityHarnessV2} from "../harness/AerodromeSingleTickLiquidityHarnessV2.sol";
import {AerodromeSingleTickLiquidityHandlerV3} from "../../src/handlers/v3/AerodromeSingleTickLiquidityHandlerV3.sol";

contract AerodromeSingleTickLiquidityHandlerV2_Test is Test {
    using TickMath for int24;

    address ETH; // token1
    address LUSD; // token0

    ERC20Mock token0;
    ERC20Mock token1;

    address clFactory = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

    AerodromeTestLib testLib;
    ICLPool pool = ICLPool(0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59); // (WETH/USDC);
    ISwapRouter swapRouter = ISwapRouter(0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5);

    int24 tickSpacing = 100;

    uint160 initSqrtPriceX96 = 1771845812700903892492222464; // 1 ETH = 2000 LUSD

    address alice = makeAddr("alice"); // main LP
    address bob = makeAddr("bob"); // protocol LP
    address jason = makeAddr("jason"); // protocol LP
    address trader = makeAddr("trader"); // option buyer
    address garbage = makeAddr("garbage"); // garbage address
    address roger = makeAddr("roger"); // roger address
    address tango = makeAddr("tango"); // tango address

    address testAddr = 0x07aE8551Be970cB1cCa11Dd7a11F47Ae82e70E67;

    DopexV2PositionManager positionManager;
    AerodromeSingleTickLiquidityHarnessV2 positionManagerHarness;
    AerodromeSingleTickLiquidityHandlerV3 handler;

    address hook = address(0);
    bytes hookData = new bytes(0);

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 23263050);

        ETH = address(new ERC20Mock());
        LUSD = address(new ERC20Mock());

        testLib = new AerodromeTestLib();
        pool = ICLPool(testLib.deployPoolAndInitializePrice(ETH, LUSD, tickSpacing, initSqrtPriceX96));

        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        testLib.addLiquidity(
            AerodromeTestLib.AddLiquidityStruct({
                user: alice,
                pool: pool,
                desiredTickLower: -78240, // 2500
                desiredTickUpper: -73130, // 1500
                desiredAmount0: 5_000_000e18,
                desiredAmount1: 0,
                requireMint: true
            })
        );

        handler = new AerodromeSingleTickLiquidityHandlerV3(clFactory, address(swapRouter));
        positionManager = new DopexV2PositionManager();

        positionManagerHarness = new AerodromeSingleTickLiquidityHarnessV2(testLib, positionManager, handler);

        positionManager.updateWhitelistHandlerWithApp(address(handler), garbage, true);
        positionManager.updateWhitelistHandler(address(handler), true);
        handler.updateWhitelistedApps(address(positionManager), true);
    }

    function testMintPosition() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -77500; // 2320
        int24 tickUpper = -77400; // 2297

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);
    }

    function testMintPositionWithOneSwap() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        uint256 amount01 = 10_000e18;
        uint256 amount11 = 0;

        int24 tickLower = -77500; // 2320
        int24 tickUpper = -77400; // 2297

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
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

        int24 tickLower = -77500; // 2320
        int24 tickUpper = -77400; // 2297

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, amount01, amount11, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
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

        int24 tickLower = -77500; // 2320
        int24 tickUpper = -77400; // 2297

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );
    }

    function testBurnPosition() public {
        int24 tickLower = -77500;
        int24 tickUpper = -77400;

        testMintPositionWithSwaps();

        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

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
        int24 tickLower = -77500;
        int24 tickUpper = -77400;

        positionManagerHarness.mintPosition(token0, token1, 0, 2, tickLower, tickUpper, pool, hook, bob);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        positionManagerHarness.mintPosition(token0, token1, 2, 0, tickLower, tickUpper, pool, hook, jason);

        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

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

        int24 tickLower = -77500;
        int24 tickUpper = -77400;

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
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

        int24 tickLower = -77500;
        int24 tickUpper = -77400;

        positionManagerHarness.unusePosition(
            amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

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

        int24 tickLower = -77500;
        int24 tickUpper = -77400;

        vm.roll(block.number + 1);

        positionManagerHarness.donatePosition(
            token0, token1, amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, garbage
        );

        vm.roll(block.number + 5);

        positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, roger);

        positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, tango);

        vm.roll(block.number + 10);

        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

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

        int24 tickLower = -75800; // ~1950
        int24 tickUpper = -75700; // ~1952

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        // console.log("Total Token 0 Borrowed", token0.balanceOf(garbage));

        AerodromeSingleTickLiquidityHandlerV3.TokenIdInfo memory tki = handler.getTokenIdData(
            uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper)))
        );
        // console.log(tl, ts, lu);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: trader,
                pool: pool,
                amountIn: 200e18, // pushes to 1921
                zeroForOne: false,
                requireMint: true
            })
        );

        // console.log(testLib.getCurrentSqrtPriceX96(pool));

        // uint256 amountToSwap = token0.balanceOf(garbage);

        // vm.startPrank(garbage);
        // token0.transfer(address(1), amountToSwap);
        // vm.stopPrank();

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token0.balanceOf(garbage), // pushes to 1925
                zeroForOne: true,
                requireMint: false
            })
        );

        // console.log("Total Token 1 after Swap", token1.balanceOf(garbage));
        // console.log(testLib.getCurrentSqrtPriceX96(pool));

        (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
            testLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            tki.liquidityUsed
        );

        // console.log(a0, a1);

        positionManagerHarness.unusePosition(a0, a1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
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

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        // console.log("Total Token 1 Borrowed", token1.balanceOf(garbage));

        AerodromeSingleTickLiquidityHandlerV3.TokenIdInfo memory tki = handler.getTokenIdData(
            uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper)))
        );
        // console.log(tl, ts, lu);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: trader,
                pool: pool,
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );

        // console.log(testLib.getCurrentSqrtPriceX96(pool));

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token1.balanceOf(garbage), // pushes to 2076
                zeroForOne: false,
                requireMint: false
            })
        );

        // console.log("Total Token 1 after Swap", token1.balanceOf(garbage));
        // console.log(testLib.getCurrentSqrtPriceX96(pool));

        (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
            testLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            tki.liquidityUsed
        );

        // console.log(a0, a1);

        positionManagerHarness.unusePosition(a0, a1, 1, 0, tickLower, tickUpper, pool, hook, hookData, garbage);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: token0.balanceOf(garbage), // pushes to 1921
                zeroForOne: true,
                requireMint: false
            })
        );

        // console.log("Profit: ", token1.balanceOf(garbage));
    }

    function testReserveLiquidity() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        handler.reserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );
        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        vm.warp(block.timestamp + 6 hours);
        vm.startPrank(bob);

        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        handler.withdrawReserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );
        vm.stopPrank();

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);

        // AerodromeSingleTickLiquidityHandlerV3.TokenIdInfo memory tki = handler
        //     .getTokenIdData(
        //         uint256(
        //             keccak256(
        //                 abi.encode(
        //                     address(handler),
        //                     pool,
        //                     tickLower,
        //                     tickUpper
        //                 )
        //             )
        //         )
        //     );
        // console.log("Total Liquidity", tki.totalLiquidity);
        // console.log("Total Supply", tki.totalSupply);
        // console.log("Liquidity Used", tki.liquidityUsed);
        // console.log("Total Reserve", tki.reservedLiquidity);
        // console.log("TokensOwed0", tki.tokensOwed0);
        // console.log("TokensOwed1", tki.tokensOwed1);
    }

    function testReserveLiquidityWithSwaps() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 910e18,
                zeroForOne: false,
                requireMint: true
            })
        );

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        handler.reserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );
        vm.stopPrank();

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
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
            AerodromeTestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 2_000_000e18,
                zeroForOne: true,
                requireMint: true
            })
        );

        testLib.performSwap(
            AerodromeTestLib.SwapParamsStruct({
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

        handler.withdrawReserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );
        vm.stopPrank();

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    function testWithdrawWithoutLiquidityUsed() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        vm.startPrank(bob);
        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        handler.reserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 6 hours);
        vm.startPrank(bob);
        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        handler.withdrawReserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );
        vm.stopPrank();

        uint256 jasonBalance =
            handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    function testFail_WithdrawReserveBeforeCooldown() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        handler.reserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );
        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        vm.startPrank(bob);
        (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
            uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        );

        handler.withdrawReserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobReserveBalance)
                })
            )
        );
        vm.stopPrank();
    }

    function testFail_WithdrawingReserveLiquidity() public {
        uint256 amount0 = 0;
        uint256 amount1 = 5e18;

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        positionManagerHarness.usePosition(amount0, amount1 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        handler.reserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );
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

        int24 tickLower = -76300; // ~2050
        int24 tickUpper = -76200; // ~2048

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

        vm.startPrank(bob);
        uint256 bobBalance =
            handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        handler.reserveLiquidity(
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(bobBalance)
                })
            )
        );
        vm.stopPrank();

        positionManagerHarness.unusePosition(
            amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        );

        positionManagerHarness.usePosition(amount0, amount1 / 2, tickLower, tickUpper, pool, hook, hookData, garbage);
    }
}
