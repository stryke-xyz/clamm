// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IPancakeV3Factory} from "../../src/pancake-v3/v3-core/contracts/interfaces/IPancakeV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IPancakeV3Pool} from "../../src/pancake-v3/v3-core/contracts/interfaces/IPancakeV3Pool.sol";

import {PancakeV3TestLib} from "../utils/pancake-v3/PancakeV3TestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {PancakeV3SingleTickLiquidityHarnessV2} from "../harness/PancakeV3SingleTickLiquidityHandlerV2.harness.sol";
import {PancakeV3SingleTickLiquidityHandlerV2} from "../../src/handlers/PancakeV3SingleTickLiquidityHandlerV2.sol";
import {DopexV2OptionMarketV2} from "../../src/DopexV2OptionMarketV2.sol";

import {OptionPricingV2} from "../../src/pricing/OptionPricingV2.sol";
import {DopexV2ClammFeeStrategyV2} from "../../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";
import {SwapRouterSwapper} from "../../src/swapper/SwapRouterSwapper.sol";
import {AutoExerciseTimeBased} from "../../src/periphery/AutoExerciseTimeBased.sol";

import {IOptionPricingV2} from "../../src/pricing/IOptionPricingV2.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";
import {ISwapper} from "../../src/interfaces/ISwapper.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";

import {BoundedTTLHook_20mins} from "../../src/handlers/hooks/sample/BoundedTTLHook_20mins.sol";

contract DopexV2OptionMarketV2PCS_0day is Test {
    using TickMath for int24;

    address ETH; // token1
    address LUSD; // token0

    ERC20Mock token0;
    ERC20Mock token1;

    PancakeV3TestLib pancakeV3TestLib;
    IUniswapV3Pool pool;

    OptionPricingV2 op;
    SwapRouterSwapper srs;

    uint24 fee = 500;

    uint160 initSqrtPriceX96 = 1771845812700903892492222464; // 1 ETH = 2000 LUSD

    int24 tickLowerCalls = -76260; // ~2050
    int24 tickUpperCalls = -76250; // ~2048

    int24 tickLowerPuts = -75770; // ~1950
    int24 tickUpperPuts = -75760; // ~1952

    uint256 premiumAmountCalls = 100;
    uint256 premiumAmountPuts = 100;

    uint256 optionIdCalls;
    uint256 optionIdPuts;

    address hook;

    address alice = makeAddr("alice"); // main LP
    address bob = makeAddr("bob"); // protocol LP
    address jason = makeAddr("jason"); // protocol LP
    address trader = makeAddr("trader"); // option buyer
    address garbage = makeAddr("garbage"); // garbage address
    address feeToAutoExercise = makeAddr("feeToAutoExercise"); // auto exercise fee to
    address autoExercisoor = makeAddr("autoExercisoor"); // auto exciseroor role

    DopexV2PositionManager positionManager;
    PancakeV3SingleTickLiquidityHarnessV2 positionManagerHarness;
    DopexV2OptionMarketV2 optionMarket;
    PancakeV3SingleTickLiquidityHandlerV2 pcsV3Handler;
    DopexV2ClammFeeStrategyV2 feeStrategy;
    AutoExerciseTimeBased autoExercise;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 180385764);

        vm.warp(1693352493);

        ETH = address(new ERC20Mock());
        LUSD = address(new ERC20Mock());

        pancakeV3TestLib = new PancakeV3TestLib();
        pool = IUniswapV3Pool(pancakeV3TestLib.deployPancakeV3PoolAndInitializePrice(ETH, LUSD, fee, initSqrtPriceX96));

        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        positionManager = new DopexV2PositionManager();

        pcsV3Handler = new PancakeV3SingleTickLiquidityHandlerV2(
            0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9,
            0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2,
            address(pancakeV3TestLib.swapRouter())
        );

        positionManagerHarness =
            new PancakeV3SingleTickLiquidityHarnessV2(pancakeV3TestLib, positionManager, pcsV3Handler);

        op = new OptionPricingV2(500, 1e8);
        srs = new SwapRouterSwapper(address(pancakeV3TestLib.swapRouter()));

        feeStrategy = new DopexV2ClammFeeStrategyV2();

        optionMarket = new DopexV2OptionMarketV2(
            address(positionManager), address(op), address(feeStrategy), ETH, LUSD, address(pool)
        );

        // Add 0.15% fee to the market
        feeStrategy.registerOptionMarket(address(optionMarket), 350000);

        uint256[] memory ttls = new uint256[](1);
        ttls[0] = 20 minutes;

        uint256[] memory IVs = new uint256[](1);
        IVs[0] = 100;

        address feeCollector = makeAddr("feeCollector");

        op.updateIVs(ttls, IVs);
        optionMarket.updateAddress(
            feeCollector, address(0), address(feeStrategy), address(op), address(this), true, address(pool), true
        );
        pancakeV3TestLib.addLiquidity(
            PancakeV3TestLib.AddLiquidityStruct({
                user: alice,
                pool: IPancakeV3Pool(address(pool)),
                desiredTickLower: -78245, // 2500
                desiredTickUpper: -73136, // 1500
                desiredAmount0: 5_000_000e18,
                desiredAmount1: 0,
                requireMint: true
            })
        );

        positionManager.updateWhitelistHandlerWithApp(address(pcsV3Handler), address(optionMarket), true);

        positionManager.updateWhitelistHandler(address(pcsV3Handler), true);

        pcsV3Handler.updateWhitelistedApps(address(positionManager), true);

        autoExercise = new AutoExerciseTimeBased();

        autoExercise.updateFeeTo(feeToAutoExercise);

        autoExercise.grantRole(keccak256("EXECUTOR"), autoExercisoor);

        hook = address(new BoundedTTLHook_20mins());

        // for calls
        positionManagerHarness.mintPosition(
            token0,
            token1,
            0,
            5e18,
            -76260, // ~2050,
            -76250, // ~2048,
            IPancakeV3Pool(address(pool)),
            hook,
            bob
        );

        positionManagerHarness.mintPosition(
            token0,
            token1,
            0,
            5e18,
            -76260, // ~2050,
            -76250, // ~2048,
            IPancakeV3Pool(address(pool)),
            hook,
            jason
        );

        // for puts
        positionManagerHarness.mintPosition(
            token0,
            token1,
            10_000e18,
            0,
            -75770, // ~1950,
            -75760, // ~1952,
            IPancakeV3Pool(address(pool)),
            hook,
            bob
        );

        positionManagerHarness.mintPosition(
            token0,
            token1,
            10_000e18,
            0,
            -75770, // ~1950,
            -75760, // ~1952,
            IPancakeV3Pool(address(pool)),
            hook,
            jason
        );
    }

    function testBuyCallOption() public {
        vm.startPrank(trader);
        uint256 l = LiquidityAmounts.getLiquidityForAmount1(
            tickLowerCalls.getSqrtRatioAtTick(), tickUpperCalls.getSqrtRatioAtTick(), 5e18
        );

        uint256 _premiumAmountCalls = optionMarket.getPremiumAmount(
            false,
            block.timestamp + 20 minutes,
            optionMarket.getPricePerCallAssetViaTick(pool, tickUpperCalls),
            optionMarket.getCurrentPricePerCallAsset(pool),
            5e18
        );

        uint256 _fee = optionMarket.getFee(0, _premiumAmountCalls);
        uint256 cost = _premiumAmountCalls + _fee;
        token1.mint(trader, cost);
        token1.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[] memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: pcsV3Handler,
            pool: pool,
            hook: hook,
            tickLower: tickLowerCalls,
            tickUpper: tickUpperCalls,
            liquidityToUse: l
        });

        optionMarket.mintOption(
            DopexV2OptionMarketV2.OptionParams({
                optionTicks: opTicks,
                tickLower: tickLowerCalls,
                tickUpper: tickUpperCalls,
                ttl: 20 minutes,
                isCall: true,
                maxCostAllowance: cost
            })
        );

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        vm.stopPrank();
    }

    function testBuyPutOption() public {
        vm.startPrank(trader);

        uint256 l = LiquidityAmounts.getLiquidityForAmount0(
            tickLowerPuts.getSqrtRatioAtTick(), tickUpperPuts.getSqrtRatioAtTick(), 10_000e18
        );

        uint256 _premiumAmountPuts = optionMarket.getPremiumAmount(
            true,
            block.timestamp + 20 minutes,
            optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts),
            optionMarket.getCurrentPricePerCallAsset(pool),
            (10_000e18 * 1e18) / optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts)
        );

        uint256 _fee = optionMarket.getFee(0, _premiumAmountPuts);
        uint256 cost = _premiumAmountPuts + _fee;
        token0.mint(trader, cost);
        token0.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[] memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: pcsV3Handler,
            pool: pool,
            hook: hook,
            tickLower: tickLowerPuts,
            tickUpper: tickUpperPuts,
            liquidityToUse: l
        });

        optionMarket.mintOption(
            DopexV2OptionMarketV2.OptionParams({
                optionTicks: opTicks,
                tickLower: tickLowerPuts,
                tickUpper: tickUpperPuts,
                ttl: 20 minutes,
                isCall: false,
                maxCostAllowance: cost
            })
        );

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        vm.stopPrank();
    }

    function testFail_BuyCallOption() public {
        vm.startPrank(trader);
        uint256 l = LiquidityAmounts.getLiquidityForAmount1(
            tickLowerCalls.getSqrtRatioAtTick(), tickUpperCalls.getSqrtRatioAtTick(), 5e18
        );

        uint256 _premiumAmountCalls = optionMarket.getPremiumAmount(
            false,
            block.timestamp + 1 hours,
            optionMarket.getPricePerCallAssetViaTick(pool, tickUpperCalls),
            optionMarket.getCurrentPricePerCallAsset(pool),
            5e18
        );

        uint256 _fee = optionMarket.getFee(0, _premiumAmountCalls);
        uint256 cost = _premiumAmountCalls + _fee;
        token1.mint(trader, cost);
        token1.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[] memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: pcsV3Handler,
            pool: pool,
            hook: hook,
            tickLower: tickLowerCalls,
            tickUpper: tickUpperCalls,
            liquidityToUse: l
        });

        optionMarket.mintOption(
            DopexV2OptionMarketV2.OptionParams({
                optionTicks: opTicks,
                tickLower: tickLowerCalls,
                tickUpper: tickUpperCalls,
                ttl: 1 hours,
                isCall: true,
                maxCostAllowance: cost
            })
        );

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        vm.stopPrank();
    }

    function testFail_BuyPutOption() public {
        vm.startPrank(trader);

        uint256 l = LiquidityAmounts.getLiquidityForAmount0(
            tickLowerPuts.getSqrtRatioAtTick(), tickUpperPuts.getSqrtRatioAtTick(), 10_000e18
        );

        uint256 _premiumAmountPuts = optionMarket.getPremiumAmount(
            true,
            block.timestamp + 1 hours,
            optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts),
            optionMarket.getCurrentPricePerCallAsset(pool),
            (10_000e18 * 1e18) / optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts)
        );

        uint256 _fee = optionMarket.getFee(0, _premiumAmountPuts);
        uint256 cost = _premiumAmountPuts + _fee;
        token0.mint(trader, cost);
        token0.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[] memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: pcsV3Handler,
            pool: pool,
            hook: hook,
            tickLower: tickLowerPuts,
            tickUpper: tickUpperPuts,
            liquidityToUse: l
        });

        optionMarket.mintOption(
            DopexV2OptionMarketV2.OptionParams({
                optionTicks: opTicks,
                tickLower: tickLowerPuts,
                tickUpper: tickUpperPuts,
                ttl: 1 hours,
                isCall: false,
                maxCostAllowance: cost
            })
        );

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        vm.stopPrank();
    }

    function testExerciseCallOption() public {
        testBuyCallOption();

        uint256 optionId = 1;

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );
        vm.startPrank(trader);

        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToExercise = new uint256[](len);

        liquidityToExercise[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        optionMarket.exerciseOption(
            DopexV2OptionMarketV2.ExerciseOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToExercise: liquidityToExercise
            })
        );

        console.log("Profit", token0.balanceOf(trader));

        vm.stopPrank();
    }

    function testExercisePutOption() public {
        testBuyPutOption();

        uint256 optionId = 1;

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 250e18,
                zeroForOne: false,
                requireMint: true
            })
        );
        vm.startPrank(trader);
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToExercise = new uint256[](len);

        liquidityToExercise[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        optionMarket.exerciseOption(
            DopexV2OptionMarketV2.ExerciseOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToExercise: liquidityToExercise
            })
        );

        console.log("Profit", token1.balanceOf(trader));

        vm.stopPrank();
    }

    function testSettleOptionCallOTM() public {
        testBuyCallOption();
        uint256 prevTime = block.timestamp + 20 minutes;
        vm.warp(block.timestamp + 1201 seconds);
        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        optionMarket.settleOption(
            DopexV2OptionMarketV2.SettleOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToSettle: liquidityToSettle
            })
        );
    }

    function testSettleOptionPutOTM() public {
        testBuyPutOption();
        uint256 prevTime = block.timestamp + 20 minutes;

        vm.warp(block.timestamp + 1201 seconds);

        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        optionMarket.settleOption(
            DopexV2OptionMarketV2.SettleOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToSettle: liquidityToSettle
            })
        );
    }

    function testSettleOptionCallITM() public {
        testBuyCallOption();
        uint256 prevTime = block.timestamp + 20 minutes;
        vm.warp(block.timestamp + 1201 seconds);

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );

        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        optionMarket.settleOption(
            DopexV2OptionMarketV2.SettleOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToSettle: liquidityToSettle
            })
        );

        console.log("Balance after settlement", token0.balanceOf(address(this)));
    }

    function testSettleOptionPutITM() public {
        testBuyPutOption();
        uint256 prevTime = block.timestamp + 20 minutes;

        vm.warp(block.timestamp + 1201 seconds);

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 250e18, // pushes to 1921
                zeroForOne: false,
                requireMint: true
            })
        );
        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        optionMarket.settleOption(
            DopexV2OptionMarketV2.SettleOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToSettle: liquidityToSettle
            })
        );

        console.log("Balance after settlement", token1.balanceOf(address(this)));
    }

    function testSettleOptionCallATM() public {
        testBuyCallOption();
        uint256 prevTime = block.timestamp + 20 minutes;
        vm.warp(block.timestamp + 1201 seconds);

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 70e18, // pushes to 2078
                zeroForOne: false,
                requireMint: true
            })
        );

        console.logInt(pancakeV3TestLib.getCurrentTick(IPancakeV3Pool(address(pool))));

        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        (uint256 a0,) = LiquidityAmounts.getAmountsForLiquidity(
            pancakeV3TestLib.getCurrentTick(IPancakeV3Pool(address(pool))).getSqrtRatioAtTick(),
            tickLowerCalls.getSqrtRatioAtTick(),
            tickUpperCalls.getSqrtRatioAtTick(),
            uint128(liquidityToUse)
        );

        token0.mint(address(this), a0);
        token0.approve(address(optionMarket), a0);

        optionMarket.settleOption(
            DopexV2OptionMarketV2.SettleOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToSettle: liquidityToSettle
            })
        );
    }

    function testSettleOptionPutATM() public {
        testBuyPutOption();
        uint256 prevTime = block.timestamp + 20 minutes;

        vm.warp(block.timestamp + 1201 seconds);

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 250e18, // pushes to 1921
                zeroForOne: false,
                requireMint: true
            })
        );

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 235000e18, // pushes to 1921
                zeroForOne: true,
                requireMint: true
            })
        );

        console.logInt(pancakeV3TestLib.getCurrentTick(IPancakeV3Pool(address(pool))));

        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        (, uint256 a1) = LiquidityAmounts.getAmountsForLiquidity(
            pancakeV3TestLib.getCurrentTick(IPancakeV3Pool(address(pool))).getSqrtRatioAtTick(),
            tickLowerCalls.getSqrtRatioAtTick(),
            tickUpperCalls.getSqrtRatioAtTick(),
            uint128(liquidityToUse)
        );

        token1.mint(address(this), a1);
        token1.approve(address(optionMarket), a1);

        optionMarket.settleOption(
            DopexV2OptionMarketV2.SettleOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToSettle: liquidityToSettle
            })
        );
    }

    function testSplitPosition() public {
        testBuyCallOption();

        uint256 optionId = 1;
        (uint256 len,,,,) = optionMarket.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            address _hook,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionMarket.opTickMap(1, 0);

        uint256[] memory l = new uint256[](len);

        l[0] = liquidityToUse / 4;

        vm.prank(optionMarket.ownerOf(1));
        optionMarket.positionSplitter(
            DopexV2OptionMarketV2.PositionSplitterParams({optionId: optionId, to: garbage, liquidityToSplit: l})
        );

        (
            IHandler p_handler,
            IUniswapV3Pool p_pool,
            address p_hook,
            int24 ptickLower,
            int24 ptickUpper,
            uint256 pliquidityToUse
        ) = optionMarket.opTickMap(1, 0);
        console.log("Previous liquidity", pliquidityToUse);

        (
            IHandler n_handler,
            IUniswapV3Pool n_pool,
            address n_hook,
            int24 ntickLower,
            int24 ntickUpper,
            uint256 nliquidityToUse
        ) = optionMarket.opTickMap(2, 0);
        console.log("New liquidity", nliquidityToUse);
    }

    function testAutoExercise() public {
        testBuyCallOption();

        uint256 optionId = 1;

        pancakeV3TestLib.performSwap(
            PancakeV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: IPancakeV3Pool(address(pool)),
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );
        vm.startPrank(trader);
        vm.warp(block.timestamp + 901);

        optionMarket.updateExerciseDelegate(address(autoExercise), true);

        vm.stopPrank();

        vm.startPrank(autoExercisoor);

        (uint256 len,,,,) = optionMarket.opData(optionId);

        (,,,,, uint256 liquidityToUse) = optionMarket.opTickMap(1, 0);

        uint256[] memory liquidityToExercise = new uint256[](len);

        liquidityToExercise[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](len);
        swapDatas[0] = abi.encode(pool.fee(), 0);

        ISwapper[] memory swappers = new ISwapper[](len);
        swappers[0] = srs;

        autoExercise.autoExercise(
            IOptionMarket(address(optionMarket)),
            optionId,
            1e4, // 1%
            IOptionMarket.ExerciseOptionParams({
                optionId: optionId,
                swapper: swappers,
                swapData: swapDatas,
                liquidityToExercise: liquidityToExercise
            })
        );

        console.log("Profit", token0.balanceOf(trader));
        console.log("AutoExerciser Profit", token0.balanceOf(feeToAutoExercise));

        vm.stopPrank();
    }
}
