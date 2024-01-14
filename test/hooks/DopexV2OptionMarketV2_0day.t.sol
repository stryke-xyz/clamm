// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {UniswapV3TestLib} from "../uniswap-v3-utils/UniswapV3TestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {UniswapV3SingleTickLiquidityHarnessV2} from "../harness/UniswapV3SingleTickLiquidityHandlerV2.harness.sol";
import {UniswapV3SingleTickLiquidityHandlerV2} from "../../src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol";
import {DopexV2OptionMarketV2} from "../../src/DopexV2OptionMarketV2.sol";

import {OptionPricing} from "../pricing/OptionPricing.sol";
import {DopexV2ClammFeeStrategy} from "../../src/pricing/fees/DopexV2ClammFeeStrategy.sol";
import {SwapRouterSwapper} from "../../src/swapper/SwapRouterSwapper.sol";
import {AutoExerciseTimeBased} from "../../src/periphery/AutoExerciseTimeBased.sol";

import {IOptionPricing} from "../../src/pricing/IOptionPricing.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";
import {ISwapper} from "../../src/interfaces/ISwapper.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";

import {BoundedTTLHook_0day} from "../../src/handlers/hooks/BoundedTTLHook_0day.sol";

contract optionMarketTest is Test {
    using TickMath for int24;

    address ETH; // token1
    address LUSD; // token0

    ERC20Mock token0;
    ERC20Mock token1;

    UniswapV3TestLib uniswapV3TestLib;
    IUniswapV3Pool pool;

    OptionPricing op;
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

    address alice = makeAddr("alice"); // main LP
    address bob = makeAddr("bob"); // protocol LP
    address jason = makeAddr("jason"); // protocol LP
    address trader = makeAddr("trader"); // option buyer
    address garbage = makeAddr("garbage"); // garbage address
    address feeToAutoExercise = makeAddr("feeToAutoExercise"); // auto exercise fee to
    address autoExercisoor = makeAddr("autoExercisoor"); // auto exciseroor role

    DopexV2PositionManager positionManager;
    UniswapV3SingleTickLiquidityHarnessV2 positionManagerHarness;
    DopexV2OptionMarketV2 optionMarket;
    UniswapV3SingleTickLiquidityHandlerV2 uniV3Handler;
    DopexV2ClammFeeStrategy feeStrategy;
    AutoExerciseTimeBased autoExercise;
    address hook;

    function setUp() public {
        vm.warp(1693352493);

        ETH = address(new ERC20Mock());
        LUSD = address(new ERC20Mock());

        uniswapV3TestLib = new UniswapV3TestLib();
        pool = IUniswapV3Pool(
            uniswapV3TestLib.deployUniswapV3PoolAndInitializePrice(
                ETH,
                LUSD,
                fee,
                initSqrtPriceX96
            )
        );

        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        positionManager = new DopexV2PositionManager();

        uniV3Handler = new UniswapV3SingleTickLiquidityHandlerV2(
            address(uniswapV3TestLib.factory()),
            0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff,
            address(uniswapV3TestLib.swapRouter())
        );

        positionManagerHarness = new UniswapV3SingleTickLiquidityHarnessV2(
            uniswapV3TestLib,
            positionManager,
            uniV3Handler
        );

        op = new OptionPricing(500, 1e8);
        srs = new SwapRouterSwapper(address(uniswapV3TestLib.swapRouter()));

        feeStrategy = new DopexV2ClammFeeStrategy();

        optionMarket = new DopexV2OptionMarketV2(
            address(positionManager),
            address(op),
            address(feeStrategy),
            ETH,
            LUSD,
            address(pool)
        );

        // Add 0.15% fee to the market
        feeStrategy.registerOptionMarket(address(optionMarket), 350000);

        uint256[] memory ttls = new uint256[](2);
        ttls[0] = 20 minutes;
        ttls[1] = 1 hours;

        uint256[] memory IVs = new uint256[](2);
        IVs[0] = 100;
        IVs[1] = 200;

        address feeCollector = makeAddr("feeCollector");

        optionMarket.updateIVs(ttls, IVs);
        optionMarket.updateAddress(
            feeCollector,
            address(0),
            address(feeStrategy),
            address(op),
            address(this),
            true,
            address(pool),
            true
        );
        uniswapV3TestLib.addLiquidity(
            UniswapV3TestLib.AddLiquidityStruct({
                user: alice,
                pool: pool,
                desiredTickLower: -78245, // 2500
                desiredTickUpper: -73136, // 1500
                desiredAmount0: 5_000_000e18,
                desiredAmount1: 0,
                requireMint: true
            })
        );

        positionManager.updateWhitelistHandlerWithApp(
            address(uniV3Handler),
            address(optionMarket),
            true
        );

        positionManager.updateWhitelistHandler(address(uniV3Handler), true);

        uniV3Handler.updateWhitelistedApps(address(positionManager), true);

        autoExercise = new AutoExerciseTimeBased();

        autoExercise.updateFeeTo(feeToAutoExercise);

        autoExercise.grantRole(keccak256("EXECUTOR"), autoExercisoor);

        hook = address(new BoundedTTLHook_0day());

        // for calls
        positionManagerHarness.mintPosition(
            token0,
            token1,
            0,
            5e18,
            -76260, // ~2050,
            -76250, // ~2048,
            pool,
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
            pool,
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
            pool,
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
            pool,
            hook,
            jason
        );
    }

    function testBuyCallOption() public {
        vm.startPrank(trader);
        uint256 l = LiquidityAmounts.getLiquidityForAmount1(
            tickLowerCalls.getSqrtRatioAtTick(),
            tickUpperCalls.getSqrtRatioAtTick(),
            5e18
        );

        uint256 _premiumAmountCalls = optionMarket.getPremiumAmount(
            false,
            block.timestamp + 20 minutes,
            optionMarket.getPricePerCallAssetViaTick(pool, tickUpperCalls),
            optionMarket.getCurrentPricePerCallAsset(pool),
            optionMarket.ttlToVol(20 minutes),
            5e18
        );

        uint256 _fee = optionMarket.getFee(0, 0, _premiumAmountCalls);
        uint256 cost = _premiumAmountCalls + _fee;
        token1.mint(trader, cost);
        token1.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[]
            memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: uniV3Handler,
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
            tickLowerPuts.getSqrtRatioAtTick(),
            tickUpperPuts.getSqrtRatioAtTick(),
            10_000e18
        );

        uint256 _premiumAmountPuts = optionMarket.getPremiumAmount(
            true,
            block.timestamp + 20 minutes,
            optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts),
            optionMarket.getCurrentPricePerCallAsset(pool),
            optionMarket.ttlToVol(20 minutes),
            (10_000e18 * 1e18) /
                optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts)
        );

        uint256 _fee = optionMarket.getFee(0, 0, _premiumAmountPuts);
        uint256 cost = _premiumAmountPuts + _fee;
        token0.mint(trader, cost);
        token0.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[]
            memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: uniV3Handler,
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
            tickLowerCalls.getSqrtRatioAtTick(),
            tickUpperCalls.getSqrtRatioAtTick(),
            5e18
        );

        uint256 _premiumAmountCalls = optionMarket.getPremiumAmount(
            false,
            block.timestamp + 1 hours,
            optionMarket.getPricePerCallAssetViaTick(pool, tickUpperCalls),
            optionMarket.getCurrentPricePerCallAsset(pool),
            optionMarket.ttlToVol(1 hours),
            5e18
        );

        uint256 _fee = optionMarket.getFee(0, 0, _premiumAmountCalls);
        uint256 cost = _premiumAmountCalls + _fee;
        token1.mint(trader, cost);
        token1.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[]
            memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: uniV3Handler,
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
            tickLowerPuts.getSqrtRatioAtTick(),
            tickUpperPuts.getSqrtRatioAtTick(),
            10_000e18
        );

        uint256 _premiumAmountPuts = optionMarket.getPremiumAmount(
            true,
            block.timestamp + 1 hours,
            optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts),
            optionMarket.getCurrentPricePerCallAsset(pool),
            optionMarket.ttlToVol(1 hours),
            (10_000e18 * 1e18) /
                optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts)
        );

        uint256 _fee = optionMarket.getFee(0, 0, _premiumAmountPuts);
        uint256 cost = _premiumAmountPuts + _fee;
        token0.mint(trader, cost);
        token0.approve(address(optionMarket), cost);

        DopexV2OptionMarketV2.OptionTicks[]
            memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarketV2.OptionTicks({
            _handler: uniV3Handler,
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

        uniswapV3TestLib.performSwap(
            UniswapV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );
        vm.startPrank(trader);

        (uint256 len, , , , ) = optionMarket.opData(optionId);

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

        uniswapV3TestLib.performSwap(
            UniswapV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 250e18,
                zeroForOne: false,
                requireMint: true
            })
        );
        vm.startPrank(trader);
        (uint256 len, , , , ) = optionMarket.opData(optionId);

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
        (uint256 len, , , , ) = optionMarket.opData(optionId);

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
        (uint256 len, , , , ) = optionMarket.opData(optionId);

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

        uniswapV3TestLib.performSwap(
            UniswapV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 400000e18, // pushes to 2078
                zeroForOne: true,
                requireMint: true
            })
        );

        uint256 optionId = 1;
        (uint256 len, , , , ) = optionMarket.opData(optionId);

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

        console.log(
            "Balance after settlement",
            token0.balanceOf(address(this))
        );
    }

    function testSettleOptionPutITM() public {
        testBuyPutOption();
        uint256 prevTime = block.timestamp + 20 minutes;

        vm.warp(block.timestamp + 1201 seconds);

        uniswapV3TestLib.performSwap(
            UniswapV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
                amountIn: 250e18, // pushes to 1921
                zeroForOne: false,
                requireMint: true
            })
        );
        uint256 optionId = 1;
        (uint256 len, , , , ) = optionMarket.opData(optionId);

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

        console.log(
            "Balance after settlement",
            token1.balanceOf(address(this))
        );
    }

    function testSplitPosition() public {
        testBuyCallOption();

        uint256 optionId = 1;
        (uint256 len, , , , ) = optionMarket.opData(optionId);

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
            DopexV2OptionMarketV2.PositionSplitterParams({
                optionId: optionId,
                to: garbage,
                liquidityToSplit: l
            })
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

        uniswapV3TestLib.performSwap(
            UniswapV3TestLib.SwapParamsStruct({
                user: garbage,
                pool: pool,
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

        (uint256 len, , , , ) = optionMarket.opData(optionId);

        (, , , , , uint256 liquidityToUse) = optionMarket.opTickMap(1, 0);

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
        console.log(
            "AutoExerciser Profit",
            token0.balanceOf(feeToAutoExercise)
        );

        vm.stopPrank();
    }
}
