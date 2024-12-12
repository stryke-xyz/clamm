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

    address clFactory = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

    ERC20Mock token0 = ERC20Mock(0x4200000000000000000000000000000000000006);
    ERC20Mock token1 = ERC20Mock(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    AerodromeTestLib testLib;
    ICLPool pool = ICLPool(0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59); // (WETH/USDC);
    ISwapRouter swapRouter = ISwapRouter(0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5);

    uint24 fee = 500;

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
        deal(address(token0), testAddr, 100_000 * 1e18);

        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 23263050);

        positionManager = new DopexV2PositionManager();

        handler = new AerodromeSingleTickLiquidityHandlerV3(clFactory, address(swapRouter));

        positionManager.updateWhitelistHandlerWithApp(address(handler), garbage, true);
        positionManager.updateWhitelistHandler(address(handler), true);
        handler.updateWhitelistedApps(address(positionManager), true);
    }

    // function testMintPosition() public {
    //     uint256 amount0 = 5e18;

    //     int24 tickLower = -194000; // 3759.31
    //     int24 tickUpper = -193900; // 3797.09

    //     (uint160 sqrtPriceX96, int24 tick,,,,) = pool.slot0();

    //     uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
    //         sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), 5e18, 0
    //     );

    //     vm.startPrank(testAddr);
    //     token0.approve(address(positionManager), amount0 * 2);

    //     uint256 shares0 = positionManager.mintPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.MintPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 liquidity: liquidityToMint
    //             })
    //         )
    //     );

    //     uint256 shares1 = positionManager.mintPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.MintPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 liquidity: liquidityToMint
    //             })
    //         )
    //     );

    //     assertEq(shares1, 61469699171306472);
    //     assertEq(shares0, 61469699171306473);
    // }

    function testMintPositionWithOneSwap() public {
        uint256 amount0 = 5e18;
        uint256 amount1 = 5e10; // 5000 USDC

        int24 tickLower = -194100; // 3759.31
        int24 tickUpper = -194000; // 3797.09

        (uint160 sqrtPriceX96, int24 tick,,,,) = pool.slot0();

        uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), amount0, 0
        );

        uint256 token1SwapAmount = (100_000 * 10e6) * 10;
        deal(address(token1), testAddr, token1SwapAmount + amount1);

        vm.startPrank(testAddr);
        token0.approve(address(positionManager), type(uint256).max);
        token1.approve(address(positionManager), type(uint256).max);
        token1.approve(address(swapRouter), token1SwapAmount);

        positionManager.mintPosition(
            handler,
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.MintPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidity: liquidityToMint
                })
            )
        );

        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                tickSpacing: int24(pool.tickSpacing()),
                recipient: testAddr,
                deadline: block.timestamp + 5 days,
                amountIn: token1SwapAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        (sqrtPriceX96, tick,,,,) = pool.slot0();

        liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), 0, amount1
        );

        positionManager.mintPosition(
            handler,
            abi.encode(
                AerodromeSingleTickLiquidityHandlerV3.MintPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidity: liquidityToMint
                })
            )
        );
    }

    function testMintPositionWithOneSwap3() public {
        uint256 amount0 = 5e18;
        uint256 amount1 = 5e10; // 5000 USDC

        int24 tickLower = -194100; // 3759.31
        int24 tickUpper = -194000; // 3797.09

        (uint160 sqrtPriceX96, int24 tick,,,,) = pool.slot0();
        console.logInt(tick);

        uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), amount0, 0
        );

        uint256 token0SwapAmount = (1000000e18) * 10;

        vm.startPrank(testAddr);

        token0.approve(address(swapRouter), token0SwapAmount);
        console.log(token0.balanceOf(testAddr));

        // swapRouter.exactInputSingle(
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: address(token0),
        //         tokenOut: address(token1),
        //         tickSpacing: int24(pool.tickSpacing()),
        //         recipient: testAddr,
        //         deadline: block.timestamp + 5 days,
        //         amountIn: token0SwapAmount,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );

        // vm.stopPrank();

        // (,  tick,,,,) = pool.slot0();
        // console.logInt(tick);

        // vm.startPrank(testAddr);
        // token0.approve(address(positionManager), type(uint256).max);
        // token1.approve(address(positionManager), type(uint256).max);
        // token1.approve(address(swapRouter), token1SwapAmount);

        // positionManager.mintPosition(
        //     handler,
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.MintPositionParams({
        //             pool: pool,
        //             hook: hook,
        //             tickLower: tickLower,
        //             tickUpper: tickUpper,
        //             liquidity: liquidityToMint
        //         })
        //     )
        // );

        // swapRouter.exactInputSingle(
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: address(token1),
        //         tokenOut: address(token0),
        //         tickSpacing: int24(pool.tickSpacing()),
        //         recipient: testAddr,
        //         deadline: block.timestamp + 5 days,
        //         amountIn: token1SwapAmount,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );

        // (sqrtPriceX96, tick,,,,) = pool.slot0();

        // liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
        //     sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), 0, amount1
        // );

        // positionManager.mintPosition(
        //     handler,
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.MintPositionParams({
        //             pool: pool,
        //             hook: hook,
        //             tickLower: tickLower,
        //             tickUpper: tickUpper,
        //             liquidity: liquidityToMint
        //         })
        //     )
        // );
    }

    // Mint position before a swap and after a swap, token1 -> token0
    // function testMintPositionWithOneSwap2() public {
    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     uint256 amount01 = 10_000e18;
    //     uint256 amount11 = 0;

    //     int24 tickLower = -77420; // 2299.8
    //     int24 tickUpper = -77410; // 2302.1

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 2_000_000e18,
    //             zeroForOne: true,
    //             requireMint: true
    //         })
    //     );

    //     positionManagerHarness.mintPosition(token0, token1, amount01, amount11, tickLower, tickUpper, pool, hook, bob);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 910e18,
    //             zeroForOne: false,
    //             requireMint: true
    //         })
    //     );

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);
    // }

    // function testMintPositionWithSwaps() public {
    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     int24 tickLower = -77420; // 2299.8
    //     int24 tickUpper = -77410; // 2302.1

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 2_000_000e18,
    //             zeroForOne: true,
    //             requireMint: true
    //         })
    //     );

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 910e18,
    //             zeroForOne: false,
    //             requireMint: true
    //         })
    //     );

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 2_000_000e18,
    //             zeroForOne: true,
    //             requireMint: true
    //         })
    //     );

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 910e18,
    //             zeroForOne: false,
    //             requireMint: true
    //         })
    //     );
    // }

    // function testBurnPosition() public {
    //     int24 tickLower = -77420;
    //     int24 tickUpper = -77410;

    //     testMintPositionWithSwaps();

    //     uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     uint256 jasonBalance =
    //         handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.burnPosition(
    //         jasonBalance - 1, // since you can't reset the shares
    //         tickLower,
    //         tickUpper,
    //         pool,
    //         hook,
    //         jason
    //     );
    // }

    // function testBurnPositionSmallValue() public {
    //     int24 tickLower = -77420;
    //     int24 tickUpper = -77410;

    //     positionManagerHarness.mintPosition(token0, token1, 0, 2, tickLower, tickUpper, pool, hook, bob);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 2_000_000e18,
    //             zeroForOne: true,
    //             requireMint: true
    //         })
    //     );

    //     positionManagerHarness.mintPosition(token0, token1, 2, 0, tickLower, tickUpper, pool, hook, jason);

    //     uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     uint256 jasonBalance =
    //         handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.burnPosition(
    //         jasonBalance - 1, // since you can't reset the shares
    //         tickLower,
    //         tickUpper,
    //         pool,
    //         hook,
    //         jason
    //     );
    // }

    // function testUsePosition() public {
    //     testMintPositionWithSwaps();
    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     int24 tickLower = -77420;
    //     int24 tickUpper = -77410;

    //     positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 2_000_000e18,
    //             zeroForOne: true,
    //             requireMint: true
    //         })
    //     );

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: 910e18,
    //             zeroForOne: false,
    //             requireMint: true
    //         })
    //     );
    // }

    // function testUnusePosition() public {
    //     testMintPosition();
    //     testUsePosition();

    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     int24 tickLower = -77420;
    //     int24 tickUpper = -77410;

    //     positionManagerHarness.unusePosition(
    //         amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, hookData, garbage
    //     );

    //     uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     uint256 jasonBalance =
    //         handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.burnPosition(
    //         jasonBalance - 1, // since you can't reset the shares
    //         tickLower,
    //         tickUpper,
    //         pool,
    //         hook,
    //         jason
    //     );
    // }

    // function testDonation() public {
    //     testMintPosition();

    //     uint256 amount0 = 0;
    //     uint256 amount1 = 0;

    //     int24 tickLower = -77420;
    //     int24 tickUpper = -77410;

    //     vm.roll(block.number + 1);

    //     positionManagerHarness.donatePosition(
    //         token0, token1, amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, garbage
    //     );

    //     vm.roll(block.number + 5);

    //     positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, roger);

    //     positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, tango);

    //     vm.roll(block.number + 10);

    //     uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     uint256 jasonBalance =
    //         handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     uint256 rogerBalance =
    //         handler.balanceOf(roger, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     uint256 tangoBalance =
    //         handler.balanceOf(tango, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.burnPosition(jasonBalance, tickLower, tickUpper, pool, hook, jason);
    //     positionManagerHarness.burnPosition(rogerBalance, tickLower, tickUpper, pool, hook, roger);
    //     positionManagerHarness.burnPosition(
    //         tangoBalance - 1, // since you can't reset the shares
    //         tickLower,
    //         tickUpper,
    //         pool,
    //         hook,
    //         tango
    //     );
    // }

    // function testPutOptionSim() public {
    //     uint256 amount0 = 10_000e18;
    //     uint256 amount1 = 0;

    //     int24 tickLower = -75770; // ~1950
    //     int24 tickUpper = -75760; // ~1952

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

    //     positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

    //     // console.log("Total Token 0 Borrowed", token0.balanceOf(garbage));

    //     AerodromeSingleTickLiquidityHandlerV3.TokenIdInfo memory tki =
    //         handler.getTokenIdData(uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper))));
    //     // console.log(tl, ts, lu);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: trader,
    //             pool: pool,
    //             amountIn: 200e18, // pushes to 1921
    //             zeroForOne: false,
    //             requireMint: true
    //         })
    //     );

    //     // console.log(testLib.getCurrentSqrtPriceX96(pool));

    //     // uint256 amountToSwap = token0.balanceOf(garbage);

    //     // vm.startPrank(garbage);
    //     // token0.transfer(address(1), amountToSwap);
    //     // vm.stopPrank();

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: token0.balanceOf(garbage), // pushes to 1925
    //             zeroForOne: true,
    //             requireMint: false
    //         })
    //     );

    //     // console.log("Total Token 1 after Swap", token1.balanceOf(garbage));
    //     // console.log(testLib.getCurrentSqrtPriceX96(pool));

    //     (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
    //         testLib.getCurrentSqrtPriceX96(pool),
    //         tickLower.getSqrtRatioAtTick(),
    //         tickUpper.getSqrtRatioAtTick(),
    //         tki.liquidityUsed
    //     );

    //     // console.log(a0, a1);

    //     positionManagerHarness.unusePosition(a0, a1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: token1.balanceOf(garbage), // pushes to 1921
    //             zeroForOne: false,
    //             requireMint: false
    //         })
    //     );

    //     // console.log("Profit: ", token0.balanceOf(garbage));
    // }

    // function testCallOptionSim() public {
    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     int24 tickLower = -76260; // ~2050
    //     int24 tickUpper = -76250; // ~2048

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

    //     positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

    //     // console.log("Total Token 1 Borrowed", token1.balanceOf(garbage));

    //     AerodromeSingleTickLiquidityHandlerV3.TokenIdInfo memory tki =
    //         handler.getTokenIdData(uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper))));
    //     // console.log(tl, ts, lu);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: trader,
    //             pool: pool,
    //             amountIn: 400000e18, // pushes to 2078
    //             zeroForOne: true,
    //             requireMint: true
    //         })
    //     );

    //     // console.log(testLib.getCurrentSqrtPriceX96(pool));

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: token1.balanceOf(garbage), // pushes to 2076
    //             zeroForOne: false,
    //             requireMint: false
    //         })
    //     );

    //     // console.log("Total Token 1 after Swap", token1.balanceOf(garbage));
    //     // console.log(testLib.getCurrentSqrtPriceX96(pool));

    //     (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
    //         testLib.getCurrentSqrtPriceX96(pool),
    //         tickLower.getSqrtRatioAtTick(),
    //         tickUpper.getSqrtRatioAtTick(),
    //         tki.liquidityUsed
    //     );

    //     // console.log(a0, a1);

    //     positionManagerHarness.unusePosition(a0, a1, 1, 0, tickLower, tickUpper, pool, hook, hookData, garbage);

    //     testLib.performSwap(
    //         AerodromeTestLib.SwapParamsStruct({
    //             user: garbage,
    //             pool: pool,
    //             amountIn: token0.balanceOf(garbage), // pushes to 1921
    //             zeroForOne: true,
    //             requireMint: false
    //         })
    //     );

    //     // console.log("Profit: ", token1.balanceOf(garbage));
    // }

    // function testReserveLiquidity() public {
    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     int24 tickLower = -76260; // ~2050
    //     int24 tickUpper = -76250; // ~2048

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

    //     positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

    //     vm.startPrank(bob);
    //     uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     handler.reserveLiquidity(
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 shares: uint128(bobBalance)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     positionManagerHarness.unusePosition(
    //         amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
    //     );

    //     vm.warp(block.timestamp + 6 hours);
    //     vm.startPrank(bob);

    //     (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
    //         uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
    //     );

    //     handler.withdrawReserveLiquidity(
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 shares: uint128(bobReserveBalance)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 jasonBalance =
    //         handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);

    //     // AerodromeSingleTickLiquidityHandlerV3.TokenIdInfo memory tki = handler
    //     //     .getTokenIdData(
    //     //         uint256(
    //     //             keccak256(
    //     //                 abi.encode(
    //     //                     address(handler),
    //     //                     pool,
    //     //                     tickLower,
    //     //                     tickUpper
    //     //                 )
    //     //             )
    //     //         )
    //     //     );
    //     // console.log("Total Liquidity", tki.totalLiquidity);
    //     // console.log("Total Supply", tki.totalSupply);
    //     // console.log("Liquidity Used", tki.liquidityUsed);
    //     // console.log("Total Reserve", tki.reservedLiquidity);
    //     // console.log("TokensOwed0", tki.tokensOwed0);
    //     // console.log("TokensOwed1", tki.tokensOwed1);
    // }

    function testReserveLiquidityWithSwaps() public {
        // uint256 amount0 = 5e18;

        // int24 tickLower = -194100; // 3759.31
        // int24 tickUpper = -194000; // 3797.09

        // (uint160 sqrtPriceX96,,,,,) = pool.slot0();

        // uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
        //     sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), amount0, 0
        // );

        // deal(address(token0), bob, 1000e18);
        // deal(address(token0), testAddr, 1000e18 * 10);
        // deal(address(token0), alice, 1000e18);

        // vm.startPrank(bob);

        // token0.approve(address(positionManager), amount0);

        // positionManager.mintPosition(
        //     handler,
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
        //             pool, hook, tickLower, tickUpper, liquidityToMint
        //         )
        //     )
        // );
        // vm.stopPrank();

        // vm.startPrank(alice);
        // token0.approve(address(positionManager), amount0);
        // positionManager.mintPosition(
        //     handler,
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
        //             pool, hook, tickLower, tickUpper, liquidityToMint
        //         )
        //     )
        // );
        // vm.stopPrank();

        // vm.startPrank(testAddr);
        // swapRouter.exactInputSingle(
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: address(token1),
        //         tokenOut: address(token0),
        //         tickSpacing: int24(pool.tickSpacing()),
        //         recipient: testAddr,
        //         deadline: block.timestamp + 5 days,
        //         amountIn: token1SwapAmount,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );
        // vm.stopPrank();

        // vm.startPrank(testAddr);

        // token0.transfer(bob, amount0);
        // token0.transfer(alice, amount0);

        // vm.stopPrank();

        // vm.startPrank(bob);

        // token0.approve(address(positionManager), amount0);

        // positionManager.mintPosition(
        //     handler,
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
        //             pool, hook, tickLower, tickUpper, liquidityToMint
        //         )
        //     )
        // );
        // vm.stopPrank();

        // vm.startPrank(alice);

        // token0.approve(address(positionManager), amount0);

        // positionManager.mintPosition(
        //     handler,
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
        //             pool, hook, tickLower, tickUpper, liquidityToMint
        //         )
        //     )
        // );
        // vm.stopPrank();

        // vm.startPrank();
        // swapRouter.exactInputSingle(
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: address(token1),
        //         tokenOut: address(token0),
        //         tickSpacing: int24(pool.tickSpacing()),
        //         recipient: testAddr,
        //         deadline: block.timestamp + 5 days,
        //         amountIn: token1SwapAmount,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );
        // vm.stopPrank();

        // positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

        // positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

        // testLib.performSwap(
        //     AerodromeTestLib.SwapParamsStruct({
        //         user: garbage,
        //         pool: pool,
        //         amountIn: 2_000_000e18,
        //         zeroForOne: true,
        //         requireMint: true
        //     })
        // );

        // testLib.performSwap(
        //     AerodromeTestLib.SwapParamsStruct({
        //         user: garbage,
        //         pool: pool,
        //         amountIn: 910e18,
        //         zeroForOne: false,
        //         requireMint: true
        //     })
        // );

        // positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

        // vm.startPrank(bob);
        // uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        // handler.reserveLiquidity(
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
        //             pool: pool,
        //             hook: hook,
        //             tickLower: tickLower,
        //             tickUpper: tickUpper,
        //             shares: uint128(bobBalance)
        //         })
        //     )
        // );
        // vm.stopPrank();

        // testLib.performSwap(
        //     AerodromeTestLib.SwapParamsStruct({
        //         user: garbage,
        //         pool: pool,
        //         amountIn: 2_000_000e18,
        //         zeroForOne: true,
        //         requireMint: true
        //     })
        // );

        // testLib.performSwap(
        //     AerodromeTestLib.SwapParamsStruct({
        //         user: garbage,
        //         pool: pool,
        //         amountIn: 910e18,
        //         zeroForOne: false,
        //         requireMint: true
        //     })
        // );

        // positionManagerHarness.unusePosition(
        //     amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
        // );

        // testLib.performSwap(
        //     AerodromeTestLib.SwapParamsStruct({
        //         user: garbage,
        //         pool: pool,
        //         amountIn: 2_000_000e18,
        //         zeroForOne: true,
        //         requireMint: true
        //     })
        // );

        // testLib.performSwap(
        //     AerodromeTestLib.SwapParamsStruct({
        //         user: garbage,
        //         pool: pool,
        //         amountIn: 910e18,
        //         zeroForOne: false,
        //         requireMint: true
        //     })
        // );

        // vm.warp(block.timestamp + 6 hours);
        // vm.startPrank(bob);

        // (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
        //     uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
        // );

        // handler.withdrawReserveLiquidity(
        //     abi.encode(
        //         AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
        //             pool: pool,
        //             hook: hook,
        //             tickLower: tickLower,
        //             tickUpper: tickUpper,
        //             shares: uint128(bobReserveBalance)
        //         })
        //     )
        // );
        // vm.stopPrank();

        // uint256 jasonBalance =
        //     handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

        // positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    }

    // function testWithdrawWithoutLiquidityUsed() public {
    //     uint256 amount0 = 0;
    //     uint256 amount1 = 5e18;

    //     int24 tickLower = -76260; // ~2050
    //     int24 tickUpper = -76250; // ~2048

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

    //     positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

    //     vm.startPrank(bob);
    //     uint256 bobBalance = handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     handler.reserveLiquidity(
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 shares: uint128(bobBalance)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.warp(block.timestamp + 6 hours);
    //     vm.startPrank(bob);
    //     (uint256 bobReserveBalance,) = handler.reservedLiquidityPerUser(
    //         uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
    //     );

    //     handler.withdrawReserveLiquidity(
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 shares: uint128(bobReserveBalance)
    //             })
    //         )
    //     );
    //     vm.stopPrank();

    //     uint256 jasonBalance =
    //         handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

    //     positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
    // }

    // function testWithdrawReserveBeforeCooldown() public {
    //     uint256 amount0 = 5e18;

    //     int24 tickLower = -194100; // 3759.31
    //     int24 tickUpper = -194000; // 3797.09

    //     (uint160 sqrtPriceX96,,,,,) = pool.slot0();

    //     uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
    //         sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), amount0, 0
    //     );

    //     vm.startPrank(testAddr);

    //     token0.approve(address(positionManager), amount0);

    //     uint256 sharesMinted = positionManager.mintPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint
    //             )
    //         )
    //     );

    //     vm.stopPrank();

    //     vm.startPrank(garbage);
    //     positionManager.usePosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.UnusePositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint - 2
    //             ),
    //             hookData
    //         )
    //     );

    //     vm.stopPrank();

    //     vm.startPrank(testAddr);
    //     handler.reserveLiquidity(abi.encode(pool, hook, tickLower, tickUpper, uint128(sharesMinted - 1)));

    //     (uint256 reserveBalance,) = handler.reservedLiquidityPerUser(
    //         uint256(keccak256(abi.encode(address(handler), pool, tickLower, tickUpper))), bob
    //     );

    //     vm.expectRevert(
    //         AerodromeSingleTickLiquidityHandlerV3.AerodromeSingleTickLiquidityHandlerV2__BeforeReserveCooldown.selector
    //     );

    //     handler.withdrawReserveLiquidity(
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams({
    //                 pool: pool,
    //                 hook: hook,
    //                 tickLower: tickLower,
    //                 tickUpper: tickUpper,
    //                 shares: uint128(reserveBalance)
    //             })
    //         )
    //     );
    // }

    // function testFailWithdrawingReserveLiquidity() public {
    //     uint256 amount0 = 5e18;

    //     int24 tickLower = -194100; // 3759.31
    //     int24 tickUpper = -194000; // 3797.09

    //     (uint160 sqrtPriceX96,,,,,) = pool.slot0();

    //     uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
    //         sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), amount0, 0
    //     );

    //     vm.startPrank(testAddr);
    //     token0.transfer(bob, amount0);
    //     token0.transfer(alice, amount0);
    //     vm.stopPrank();

    //     vm.startPrank(bob);
    //     token0.approve(address(positionManager), amount0);
    //     positionManager.mintPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint
    //             )
    //         )
    //     );
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     token0.approve(address(positionManager), amount0);
    //     uint256 sharesMinted = positionManager.mintPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint
    //             )
    //         )
    //     );
    //     vm.stopPrank();
    //     // positionManager.

    //     vm.startPrank(garbage);
    //     positionManager.usePosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.UnusePositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint - 1
    //             ),
    //             hookData
    //         )
    //     );

    //     positionManager.usePosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.UnusePositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint - 3
    //             ),
    //             hookData
    //         )
    //     );

    //     vm.stopPrank();

    //     vm.prank(bob);
    //     handler.reserveLiquidity(abi.encode(pool, hook, tickLower, tickUpper, uint128(sharesMinted)));

    //     positionManager.burnPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams(
    //                 pool, hook, tickLower, tickUpper, uint128(sharesMinted / 2)
    //             )
    //         )
    //     );
    // }

    // function testUsePositionWhenLiquidityInsufficient() public {
    //     uint256 amount0 = 5e18;

    //     int24 tickLower = -194100; // 3759.31
    //     int24 tickUpper = -194000; // 3797.09

    //     (uint160 sqrtPriceX96,,,,,) = pool.slot0();

    //     uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
    //         sqrtPriceX96, tickLower.getSqrtRatioAtTick(), tickUpper.getSqrtRatioAtTick(), amount0, 0
    //     );

    //     vm.startPrank(testAddr);

    //     token0.approve(address(positionManager), amount0 * 5);
    //     uint256 sharesMinted = positionManager.mintPosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.MintPositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToMint
    //             )
    //         )
    //     );

    //     vm.stopPrank();

    //     uint256 tokenId = 115371694327387080946772577486635624533280613200419859210529426370037682020816;

    //     uint128 liquidityToUse = handler.convertToAssets(uint128(sharesMinted), tokenId) - 2;
    //     uint128 sharesToReserve = handler.convertToShares(uint128(liquidityToUse), tokenId);

    //     vm.prank(garbage);
    //     positionManager.usePosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.UnusePositionParams(
    //                 pool, hook, tickLower, tickUpper, (liquidityToUse)
    //             ),
    //             hookData
    //         )
    //     );

    //     vm.prank(testAddr);
    //     handler.reserveLiquidity(
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.BurnPositionParams(
    //                 pool, hook, tickLower, tickUpper, sharesToReserve
    //             )
    //         )
    //     );

    //     vm.startPrank(garbage);

    //     token0.approve(address(positionManager), amount0);

    //     positionManager.unusePosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.UnusePositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToUse
    //             ),
    //             hookData
    //         )
    //     );

    //     vm.expectRevert(
    //         AerodromeSingleTickLiquidityHandlerV3.AerodromeSingleTickLiquidityHandlerV2__InsufficientLiquidity.selector
    //     );
    //     positionManager.usePosition(
    //         handler,
    //         abi.encode(
    //             AerodromeSingleTickLiquidityHandlerV3.UnusePositionParams(
    //                 pool, hook, tickLower, tickUpper, liquidityToUse / 2
    //             ),
    //             hookData
    //         )
    //     );
    // }
}
