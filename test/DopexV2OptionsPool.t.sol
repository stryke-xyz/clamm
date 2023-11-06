// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {UniswapV3TestLib} from "./uniswap-v3-utils/UniswapV3TestLib.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {PositionManagerHandler} from "./handlers/PositionManager.handler.sol";
import {UniswapV3SingleTickLiquidityHandler} from "../src/handlers/UniswapV3SingleTickLiquidityHandler.sol";
import {DopexV2OptionPools} from "../src/DopexV2OptionPools.sol";

import {OptionPricing} from "../src/pricing/OptionPricing.sol";
import {DopexFee} from "../src/pricing/DopexFee.sol";
import {SwapRouterSwapper} from "../src/swapper/SwapRouterSwapper.sol";

import {IOptionPricing} from "../src/pricing/IOptionPricing.sol";
import {IHandler} from "../src/interfaces/IHandler.sol";

contract OptionPoolsTest is Test {
    using TickMath for int24;

    address ETH; // token1
    address LUSD; // token0

    ERC20Mock token0;
    ERC20Mock token1;

    UniswapV3TestLib uniswapV3TestLib;
    IUniswapV3Pool pool;

    OptionPricing op;
    DopexFee dpFee;
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

    DopexV2PositionManager positionManager;
    PositionManagerHandler positionManagerHandler;
    DopexV2OptionPools optionPools;
    UniswapV3SingleTickLiquidityHandler uniV3Handler;

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

        uniV3Handler = new UniswapV3SingleTickLiquidityHandler(
            address(uniswapV3TestLib.factory()),
            0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff,
            address(uniswapV3TestLib.swapRouter())
        );

        positionManagerHandler = new PositionManagerHandler(
            uniswapV3TestLib,
            positionManager,
            uniV3Handler
        );

        op = new OptionPricing(500, 1e8);
        dpFee = new DopexFee();
        srs = new SwapRouterSwapper(address(uniswapV3TestLib.swapRouter()));

        optionPools = new DopexV2OptionPools(
            address(positionManager),
            address(op),
            address(dpFee),
            ETH,
            LUSD,
            address(pool)
        );

        // positionManager.updateWhitelist(address(optionPools), true);
        uint256[] memory ttls = new uint256[](1);
        ttls[0] = 20 minutes;

        uint256[] memory IVs = new uint256[](1);
        IVs[0] = 100;

        optionPools.updateIVs(ttls, IVs);
        optionPools.updateAddress(
            address(0),
            address(0),
            address(dpFee),
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
            address(optionPools),
            true
        );

        positionManager.updateWhitelistHandler(address(uniV3Handler), true);

        uniV3Handler.updateWhitelistedApps(address(positionManager), true);

        // for calls
        positionManagerHandler.mintPosition(
            token0,
            token1,
            0,
            5e18,
            -76260, // ~2050,
            -76250, // ~2048,
            pool,
            bob
        );

        positionManagerHandler.mintPosition(
            token0,
            token1,
            0,
            5e18,
            -76260, // ~2050,
            -76250, // ~2048,
            pool,
            jason
        );

        // for puts
        positionManagerHandler.mintPosition(
            token0,
            token1,
            10_000e18,
            0,
            -75770, // ~1950,
            -75760, // ~1952,
            pool,
            bob
        );

        positionManagerHandler.mintPosition(
            token0,
            token1,
            10_000e18,
            0,
            -75770, // ~1950,
            -75760, // ~1952,
            pool,
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

        uint256 _premiumAmountCalls = optionPools.getPremiumAmount(
            false,
            block.timestamp + 20 minutes,
            optionPools.getPricePerCallAssetViaTick(pool, tickUpperCalls),
            optionPools.getCurrentPricePerCallAsset(pool),
            optionPools.ttlToVEID(20 minutes),
            5e18
        );

        token1.mint(trader, _premiumAmountCalls);
        token1.approve(address(optionPools), _premiumAmountCalls);

        DopexV2OptionPools.OptionTicks[]
            memory opTicks = new DopexV2OptionPools.OptionTicks[](1);

        opTicks[0] = DopexV2OptionPools.OptionTicks({
            _handler: uniV3Handler,
            pool: pool,
            tickLower: tickLowerCalls,
            tickUpper: tickUpperCalls,
            liquidityToUse: l
        });

        optionPools.mintOption(
            DopexV2OptionPools.OptionParams({
                optionTicks: opTicks,
                tickLower: tickLowerCalls,
                tickUpper: tickUpperCalls,
                ttl: 20 minutes,
                isCall: true,
                maxFeeAllowed: _premiumAmountCalls
            })
        );

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        // console.log(address(_handler), address(_pool));
        // console.logInt(tickLower);
        // console.logInt(tickUpper);
        // console.log(liquidityToUse);

        vm.stopPrank();
    }

    function testBuyPutOption() public {
        vm.startPrank(trader);

        uint256 l = LiquidityAmounts.getLiquidityForAmount0(
            tickLowerPuts.getSqrtRatioAtTick(),
            tickUpperPuts.getSqrtRatioAtTick(),
            10_000e18
        );

        uint256 _premiumAmountPuts = optionPools.getPremiumAmount(
            true,
            block.timestamp + 20 minutes,
            optionPools.getPricePerCallAssetViaTick(pool, tickLowerPuts),
            optionPools.getCurrentPricePerCallAsset(pool),
            optionPools.ttlToVEID(20 minutes),
            10_000e18
        );

        token0.mint(trader, _premiumAmountPuts);
        token0.approve(address(optionPools), _premiumAmountPuts);

        DopexV2OptionPools.OptionTicks[]
            memory opTicks = new DopexV2OptionPools.OptionTicks[](1);

        opTicks[0] = DopexV2OptionPools.OptionTicks({
            _handler: uniV3Handler,
            pool: pool,
            tickLower: tickLowerPuts,
            tickUpper: tickUpperPuts,
            liquidityToUse: l
        });

        optionPools.mintOption(
            DopexV2OptionPools.OptionParams({
                optionTicks: opTicks,
                tickLower: tickLowerPuts,
                tickUpper: tickUpperPuts,
                ttl: 20 minutes,
                isCall: false,
                maxFeeAllowed: _premiumAmountPuts
            })
        );

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        // console.log(address(_handler), address(_pool));
        // console.logInt(tickLower);
        // console.logInt(tickUpper);
        // console.log(liquidityToUse);

        vm.stopPrank();
    }

    function testExerciseCallOption() public {
        testBuyCallOption();

        uint256 optionId = 2;

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

        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory liquidityToExercise = new uint256[](len);

        liquidityToExercise[0] = liquidityToUse;

        bytes memory swapData = abi.encode(pool.fee(), 0);

        optionPools.exerciseOption(
            DopexV2OptionPools.ExerciseOptionParams({
                optionId: optionId,
                swapper: srs,
                swapData: swapData,
                liquidityToExercise: liquidityToExercise
            })
        );

        console.log("Profit", token0.balanceOf(trader));

        vm.stopPrank();
    }

    function testExercisePutOption() public {
        testBuyPutOption();

        uint256 optionId = 2;

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
        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory liquidityToExercise = new uint256[](len);

        liquidityToExercise[0] = liquidityToUse;
        bytes memory swapData = abi.encode(pool.fee(), 0);

        optionPools.exerciseOption(
            DopexV2OptionPools.ExerciseOptionParams({
                optionId: optionId,
                swapper: srs,
                swapData: swapData,
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
        uint256 optionId = 2;
        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;
        bytes memory swapData = abi.encode(pool.fee(), 0);

        optionPools.settleOption(
            DopexV2OptionPools.SettleOptionParams({
                optionId: optionId,
                swapper: srs,
                swapData: swapData,
                liquidityToSettle: liquidityToSettle
            })
        );
    }

    function testSettleOptionPutOTM() public {
        testBuyPutOption();
        uint256 prevTime = block.timestamp + 20 minutes;

        vm.warp(block.timestamp + 1201 seconds);

        uint256 optionId = 2;
        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;
        bytes memory swapData = abi.encode(pool.fee(), 0);

        optionPools.settleOption(
            DopexV2OptionPools.SettleOptionParams({
                optionId: optionId,
                swapper: srs,
                swapData: swapData,
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

        uint256 optionId = 2;
        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;
        bytes memory swapData = abi.encode(pool.fee(), 0);

        optionPools.settleOption(
            DopexV2OptionPools.SettleOptionParams({
                optionId: optionId,
                swapper: srs,
                swapData: swapData,
                liquidityToSettle: liquidityToSettle
            })
        );

        console.log(token0.balanceOf(address(this)));
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
        uint256 optionId = 2;
        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory liquidityToSettle = new uint256[](len);

        liquidityToSettle[0] = liquidityToUse;
        bytes memory swapData = abi.encode(pool.fee(), 0);

        optionPools.settleOption(
            DopexV2OptionPools.SettleOptionParams({
                optionId: optionId,
                swapper: srs,
                swapData: swapData,
                liquidityToSettle: liquidityToSettle
            })
        );

        console.log(token1.balanceOf(address(this)));
    }

    function testSplitPosition() public {
        testBuyCallOption();

        uint256 optionId = 2;
        (uint256 len, , , , ) = optionPools.opData(optionId);

        (
            IHandler _handler,
            IUniswapV3Pool _pool,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidityToUse
        ) = optionPools.opTickMap(2, 0);

        uint256[] memory l = new uint256[](len);

        l[0] = liquidityToUse / 4;

        vm.prank(optionPools.ownerOf(2));
        optionPools.positionSplitter(
            DopexV2OptionPools.PositionSplitterParams({
                optionId: optionId,
                to: garbage,
                liquidityToSplit: l
            })
        );

        (
            IHandler p_handler,
            IUniswapV3Pool p_pool,
            int24 ptickLower,
            int24 ptickUpper,
            uint256 pliquidityToUse
        ) = optionPools.opTickMap(2, 0);
        console.log(pliquidityToUse);

        (
            IHandler n_handler,
            IUniswapV3Pool n_pool,
            int24 ntickLower,
            int24 ntickUpper,
            uint256 nliquidityToUse
        ) = optionPools.opTickMap(3, 0);
        console.log(nliquidityToUse);
    }
}
