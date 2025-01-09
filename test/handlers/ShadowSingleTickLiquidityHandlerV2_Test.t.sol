// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";

// import {EqualizerV3TestLib} from "../utils/equalizer-v3/EqualizerV3TestLib.sol";
// import {ERC20Mock} from "../mocks/ERC20Mock.sol";
// import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
// import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
// import {ISwapRouter} from "../../src/shadow/ISwapRouter.sol";

// import {IUniswapV3Pool} from "../../src/equalizer-v3/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
// import {EqualizerV3SingleTickLiquidityHarnessV2} from "../harness/EqualizerV3SingleTickLiquidityHarnessV2.sol";
// import {EqualizerV3SingleTickLiquidityHandlerV2} from "../../src/handlers/EqualizerV3SingleTickLiquidityHandlerV2.sol";

// contract ShadowSingleTickLiquidityHandlerV2_Test is Test {
//     using TickMath for int24;

//     address ETH; // token1
//     address LUSD; // token0

//     address v3factory = 0x7Ca1dCCFB4f49564b8f13E18a67747fd428F1C40;

//     ERC20Mock token0;
//     ERC20Mock token1;

//     EqualizerV3TestLib equalizerV3TestLib;
//     IUniswapV3Pool pool;

//     int24 tickSpacing = 8;

//     uint160 initSqrtPriceX96 = 1771845812700903892492222464; // 1 FTM = 2000 LUSD

//     address alice = makeAddr("alice"); // main LP
//     address bob = makeAddr("bob"); // protocol LP
//     address jason = makeAddr("jason"); // protocol LP
//     address trader = makeAddr("trader"); // option buyer
//     address garbage = makeAddr("garbage"); // garbage address
//     address roger = makeAddr("roger"); // roger address
//     address tango = makeAddr("tango"); // tango address

//     DopexV2PositionManager positionManager;
//     EqualizerV3SingleTickLiquidityHarnessV2 positionManagerHarness;
//     EqualizerV3SingleTickLiquidityHandlerV2 equalizerV3Handler;

//     ISwapRouter02 swapRouter = ISwapRouter02(0xE4Ba08712C404042b8EEfC3fdF3b603c977500dF);

//     address hook = address(0);
//     bytes hookData = new bytes(0);

//     function setUp() public {
//         vm.createSelectFork(vm.envString("SONIC_RPC_URL"), 606919);

//         ETH = address(new ERC20Mock());
//         LUSD = address(new ERC20Mock());

//         equalizerV3TestLib = new EqualizerV3TestLib(v3factory, address(swapRouter));

//         pool = IUniswapV3Pool(
//             equalizerV3TestLib.deployEqualizerV3PoolAndInitializePrice(ETH, LUSD, tickSpacing, initSqrtPriceX96)
//         );

//         token0 = ERC20Mock(pool.token0());
//         token1 = ERC20Mock(pool.token1());

//         equalizerV3TestLib.addLiquidity(
//             EqualizerV3TestLib.AddLiquidityStruct({
//                 user: alice,
//                 pool: pool,
//                 desiredTickLower: -78200,
//                 desiredTickUpper: -73104,
//                 desiredAmount0: 5_000_000e18,
//                 desiredAmount1: 0,
//                 requireMint: true
//             })
//         );

//         positionManager = new DopexV2PositionManager();

//         equalizerV3Handler = new EqualizerV3SingleTickLiquidityHandlerV2(v3factory, address(swapRouter));

//         positionManagerHarness =
//             new EqualizerV3SingleTickLiquidityHarnessV2(equalizerV3TestLib, positionManager, equalizerV3Handler);

//         positionManager.updateWhitelistHandlerWithApp(address(equalizerV3Handler), garbage, true);

//         positionManager.updateWhitelistHandler(address(equalizerV3Handler), true);

//         equalizerV3Handler.updateWhitelistedApps(address(positionManager), true);
//     }

//     function testMintPosition() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -77416;
//         int24 tickUpper = -77408;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);
//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);
//     }

//     function testMintPositionWithOneSwap() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         uint256 amount01 = 10_000e18;
//         uint256 amount11 = 0;

//         int24 tickLower = -77416; // 2299.8
//         int24 tickUpper = -77408; // 2302.1

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );
//         // positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);
//         vm.roll(block.number + 5);

//         positionManagerHarness.mintPosition(token0, token1, amount01, amount11, tickLower, tickUpper, pool, hook, jason);
//     }

//     function testMintPositionWithOneSwap2() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         uint256 amount01 = 10_000e18;
//         uint256 amount11 = 0;

//         int24 tickLower = -77416; // 2299.8
//         int24 tickUpper = -77408; // 2302.1

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         positionManagerHarness.mintPosition(token0, token1, amount01, amount11, tickLower, tickUpper, pool, hook, bob);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);
//     }

//     function testMintPositionWithSwaps() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -77416; // 2299.8
//         int24 tickUpper = -77408; // 2302.1

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );
//     }

//     function testBurnPosition() public {
//         int24 tickLower = -77416;
//         int24 tickUpper = -77408;

//         testMintPositionWithSwaps();

//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.burnPosition(
//             jasonBalance - 1, // since you can't reset the shares
//             tickLower,
//             tickUpper,
//             pool,
//             hook,
//             jason
//         );
//     }

//     function testBurnPositionSmallValue() public {
//         int24 tickLower = -77416;
//         int24 tickUpper = -77408;

//         positionManagerHarness.mintPosition(token0, token1, 0, 2, tickLower, tickUpper, pool, hook, bob);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         positionManagerHarness.mintPosition(token0, token1, 2, 0, tickLower, tickUpper, pool, hook, jason);

//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.burnPosition(
//             jasonBalance - 1, // since you can't reset the shares
//             tickLower,
//             tickUpper,
//             pool,
//             hook,
//             jason
//         );
//     }

//     function testUsePosition() public {
//         testMintPositionWithSwaps();
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -77416;
//         int24 tickUpper = -77408;

//         positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );
//     }

//     function testUnusePosition() public {
//         testMintPosition();
//         testUsePosition();

//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -77416;
//         int24 tickUpper = -77408;

//         positionManagerHarness.unusePosition(
//             amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, hookData, garbage
//         );

//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.burnPosition(
//             jasonBalance - 1, // since you can't reset the shares
//             tickLower,
//             tickUpper,
//             pool,
//             hook,
//             jason
//         );
//     }

//     function testDonation() public {
//         testMintPosition();

//         uint256 amount0 = 0;
//         uint256 amount1 = 0;

//         int24 tickLower = -77416;
//         int24 tickUpper = -77408;

//         vm.roll(block.number + 1);

//         positionManagerHarness.donatePosition(
//             token0, token1, amount0, amount1, 0, 1e18, tickLower, tickUpper, pool, hook, garbage
//         );

//         vm.roll(block.number + 5);

//         positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, roger);

//         positionManagerHarness.mintPosition(token0, token1, 0, 5e18, tickLower, tickUpper, pool, hook, tango);

//         vm.roll(block.number + 10);

//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         uint256 rogerBalance =
//             equalizerV3Handler.balanceOf(roger, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         uint256 tangoBalance =
//             equalizerV3Handler.balanceOf(tango, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(bobBalance, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.burnPosition(jasonBalance, tickLower, tickUpper, pool, hook, jason);
//         positionManagerHarness.burnPosition(rogerBalance, tickLower, tickUpper, pool, hook, roger);
//         positionManagerHarness.burnPosition(
//             tangoBalance - 1, // since you can't reset the shares
//             tickLower,
//             tickUpper,
//             pool,
//             hook,
//             tango
//         );
//     }

//     function testPutOptionSim() public {
//         uint256 amount0 = 10_000e18;
//         uint256 amount1 = 0;

//         int24 tickLower = -75776; // ~1950
//         int24 tickUpper = -75768; // ~1952

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

//         EqualizerV3SingleTickLiquidityHandlerV2.TokenIdInfo memory tki = equalizerV3Handler.getTokenIdData(
//             uint256(keccak256(abi.encode(address(equalizerV3Handler), pool, hook, tickLower, tickUpper)))
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: trader,
//                 pool: pool,
//                 amountIn: 200e18, // pushes to 1921
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );

//         // uint256 amountToSwap = token0.balanceOf(garbage);

//         // vm.startPrank(garbage);
//         // token0.transfer(address(1), amountToSwap);
//         // vm.stopPrank();

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: token0.balanceOf(garbage), // pushes to 1925
//                 zeroForOne: true,
//                 requireMint: false
//             })
//         );

//         // console.log("Total Token 1 after Swap", token1.balanceOf(garbage));
//         // console.log(equalizerV3TestLib.getCurrentSqrtPriceX96(pool));

//         (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
//             equalizerV3TestLib.getCurrentSqrtPriceX96(pool),
//             tickLower.getSqrtRatioAtTick(),
//             tickUpper.getSqrtRatioAtTick(),
//             tki.liquidityUsed
//         );

//         // console.log(a0, a1);

//         positionManagerHarness.unusePosition(a0, a1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: token1.balanceOf(garbage), // pushes to 1921
//                 zeroForOne: false,
//                 requireMint: false
//             })
//         );

//         // console.log("Profit: ", token0.balanceOf(garbage));
//     }

//     function testCallOptionSim() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

//         // console.log("Total Token 1 Borrowed", token1.balanceOf(garbage));

//         EqualizerV3SingleTickLiquidityHandlerV2.TokenIdInfo memory tki = equalizerV3Handler.getTokenIdData(
//             uint256(keccak256(abi.encode(address(equalizerV3Handler), pool, hook, tickLower, tickUpper)))
//         );
//         // console.log(tl, ts, lu);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: trader,
//                 pool: pool,
//                 amountIn: 400000e18, // pushes to 2078
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         // console.log(equalizerV3TestLib.getCurrentSqrtPriceX96(pool));

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: token1.balanceOf(garbage), // pushes to 2076
//                 zeroForOne: false,
//                 requireMint: false
//             })
//         );

//         // console.log("Total Token 1 after Swap", token1.balanceOf(garbage));
//         // console.log(equalizerV3TestLib.getCurrentSqrtPriceX96(pool));

//         (uint256 a0, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
//             equalizerV3TestLib.getCurrentSqrtPriceX96(pool),
//             tickLower.getSqrtRatioAtTick(),
//             tickUpper.getSqrtRatioAtTick(),
//             tki.liquidityUsed
//         );

//         // console.log(a0, a1);

//         positionManagerHarness.unusePosition(a0, a1, 1, 0, tickLower, tickUpper, pool, hook, hookData, garbage);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: token0.balanceOf(garbage), // pushes to 1921
//                 zeroForOne: true,
//                 requireMint: false
//             })
//         );

//         // console.log("Profit: ", token1.balanceOf(garbage));
//     }

//     function testReserveLiquidity() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

//         vm.startPrank(bob);
//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         equalizerV3Handler.reserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         positionManagerHarness.unusePosition(
//             amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
//         );

//         vm.warp(block.timestamp + 6 hours);
//         vm.startPrank(bob);

//         (uint256 bobReserveBalance,) = equalizerV3Handler.reservedLiquidityPerUser(
//             uint256(keccak256(abi.encode(address(equalizerV3Handler), pool, tickLower, tickUpper))), bob
//         );

//         equalizerV3Handler.withdrawReserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobReserveBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);

//         // EqualizerV3SingleTickLiquidityHandlerV2.TokenIdInfo memory tki = equalizerV3Handler
//         //     .getTokenIdData(
//         //         uint256(
//         //             keccak256(
//         //                 abi.encode(
//         //                     address(equalizerV3Handler),
//         //                     pool,
//         //                     tickLower,
//         //                     tickUpper
//         //                 )
//         //             )
//         //         )
//         //     );
//         // console.log("Total Liquidity", tki.totalLiquidity);
//         // console.log("Total Supply", tki.totalSupply);
//         // console.log("Liquidity Used", tki.liquidityUsed);
//         // console.log("Total Reserve", tki.reservedLiquidity);
//         // console.log("TokensOwed0", tki.tokensOwed0);
//         // console.log("TokensOwed1", tki.tokensOwed1);
//     }

//     function testReserveLiquidityWithSwaps() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );

//         positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

//         vm.startPrank(bob);
//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         equalizerV3Handler.reserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );

//         positionManagerHarness.unusePosition(
//             amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 2_000_000e18,
//                 zeroForOne: true,
//                 requireMint: true
//             })
//         );

//         equalizerV3TestLib.performSwap(
//             EqualizerV3TestLib.SwapParamsStruct({
//                 user: garbage,
//                 pool: pool,
//                 amountIn: 910e18,
//                 zeroForOne: false,
//                 requireMint: true
//             })
//         );

//         vm.warp(block.timestamp + 6 hours);
//         vm.startPrank(bob);

//         (uint256 bobReserveBalance,) = equalizerV3Handler.reservedLiquidityPerUser(
//             uint256(keccak256(abi.encode(address(equalizerV3Handler), pool, tickLower, tickUpper))), bob
//         );

//         equalizerV3Handler.withdrawReserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobReserveBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
//     }

//     function testWithdrawWithoutLiquidityUsed() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         vm.startPrank(bob);
//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         equalizerV3Handler.reserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         vm.warp(block.timestamp + 6 hours);
//         vm.startPrank(bob);
//         (uint256 bobReserveBalance,) = equalizerV3Handler.reservedLiquidityPerUser(
//             uint256(keccak256(abi.encode(address(equalizerV3Handler), pool, tickLower, tickUpper))), bob
//         );

//         equalizerV3Handler.withdrawReserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobReserveBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
//     }

//     function testFail_WithdrawReserveBeforeCooldown() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

//         vm.startPrank(bob);
//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         equalizerV3Handler.reserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         positionManagerHarness.unusePosition(
//             amount0, 10e18 - 3, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
//         );

//         vm.startPrank(bob);
//         (uint256 bobReserveBalance,) = equalizerV3Handler.reservedLiquidityPerUser(
//             uint256(keccak256(abi.encode(address(equalizerV3Handler), pool, tickLower, tickUpper))), bob
//         );

//         equalizerV3Handler.withdrawReserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobReserveBalance)
//                 })
//             )
//         );
//         vm.stopPrank();
//     }

//     function testFail_WithdrawingReserveLiquidity() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         positionManagerHarness.usePosition(amount0, amount1, tickLower, tickUpper, pool, hook, hookData, garbage);

//         positionManagerHarness.usePosition(amount0, amount1 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

//         vm.startPrank(bob);
//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         equalizerV3Handler.reserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         positionManagerHarness.unusePosition(
//             amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
//         );

//         uint256 jasonBalance =
//             equalizerV3Handler.balanceOf(jason, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         positionManagerHarness.burnPosition(jasonBalance - 1, tickLower, tickUpper, pool, hook, jason);
//     }

//     function testFail_UsingReservedLiqudiity() public {
//         uint256 amount0 = 0;
//         uint256 amount1 = 5e18;

//         int24 tickLower = -76264;
//         int24 tickUpper = -76256;

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, bob);

//         positionManagerHarness.mintPosition(token0, token1, amount0, amount1, tickLower, tickUpper, pool, hook, jason);

//         positionManagerHarness.usePosition(amount0, 10e18 - 3, tickLower, tickUpper, pool, hook, hookData, garbage);

//         vm.startPrank(bob);
//         uint256 bobBalance =
//             equalizerV3Handler.balanceOf(bob, positionManagerHarness.getTokenId(pool, hook, tickLower, tickUpper));

//         equalizerV3Handler.reserveLiquidity(
//             abi.encode(
//                 EqualizerV3SingleTickLiquidityHandlerV2.BurnPositionParams({
//                     pool: pool,
//                     hook: hook,
//                     tickLower: tickLower,
//                     tickUpper: tickUpper,
//                     shares: uint128(bobBalance)
//                 })
//             )
//         );
//         vm.stopPrank();

//         positionManagerHarness.unusePosition(
//             amount0, amount1, 0, 1, tickLower, tickUpper, pool, hook, hookData, garbage
//         );

//         positionManagerHarness.usePosition(amount0, amount1 / 2, tickLower, tickUpper, pool, hook, hookData, garbage);
//     }
// }
