// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {UniswapV3TestLib} from "../uniswap-v3-utils/UniswapV3TestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {UniswapV3SingleTickLiquidityHarnessV2} from "../harness/UniswapV3SingleTickLiquidityHandlerV2.harness.sol";
import {UniswapV3SingleTickLiquidityHandlerV2} from "../../src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol";
import {DopexV2OptionMarketV2} from "../../src/DopexV2OptionMarketV2.sol";

import {OptionPricingV2} from "../pricing/OptionPricingV2.sol";
import {DopexV2ClammFeeStrategyV2} from "../../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";
import {SwapRouterSwapper} from "../../src/swapper/SwapRouterSwapper.sol";
import {AutoExerciseTimeBased} from "../../src/periphery/AutoExerciseTimeBased.sol";

import {IOptionPricingV2} from "../../src/pricing/IOptionPricingV2.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";
import {ISwapper} from "../../src/interfaces/ISwapper.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";

import {
    LimitOrders,
    LimitPurchaseOrder,
    BlockTradeOrder,
    Order,
    Signature
} from "../../src/periphery/limit-orders/LimitOrders.sol";

contract LimitOrdersTest is Test {
    using TickMath for int24;

    address ETH; // token1
    address LUSD; // token0

    ERC20Mock token0;
    ERC20Mock token1;

    UniswapV3TestLib uniswapV3TestLib;
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

    address hook = address(0);
    bytes hookData = new bytes(0);

    address alice = makeAddr("alice"); // main LP
    address bob = makeAddr("bob"); // protocol LP
    address jason = makeAddr("jason"); // protocol LP
    address trader = makeAddr("trader"); // option buyer
    address garbage = makeAddr("garbage"); // garbage address
    address bot = makeAddr("bot");
    address feeToAutoExercise = makeAddr("feeToAutoExercise"); // auto exercise fee to
    address autoExercisoor = makeAddr("autoExercisoor"); // auto exciseroor role

    DopexV2PositionManager positionManager;
    UniswapV3SingleTickLiquidityHarnessV2 positionManagerHarness;
    DopexV2OptionMarketV2 optionMarket;
    UniswapV3SingleTickLiquidityHandlerV2 uniV3Handler;
    DopexV2ClammFeeStrategyV2 feeStrategy;
    AutoExerciseTimeBased autoExercise;

    LimitOrders limitOrders;

    function setUp() public {
        vm.warp(1693352493);

        ETH = address(new ERC20Mock());
        LUSD = address(new ERC20Mock());

        uniswapV3TestLib = new UniswapV3TestLib();
        pool = IUniswapV3Pool(uniswapV3TestLib.deployUniswapV3PoolAndInitializePrice(ETH, LUSD, fee, initSqrtPriceX96));

        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        positionManager = new DopexV2PositionManager();

        limitOrders = new LimitOrders();
        uniV3Handler = new UniswapV3SingleTickLiquidityHandlerV2(
            address(uniswapV3TestLib.factory()),
            0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff,
            address(uniswapV3TestLib.swapRouter())
        );

        positionManagerHarness =
            new UniswapV3SingleTickLiquidityHarnessV2(uniswapV3TestLib, positionManager, uniV3Handler);

        op = new OptionPricingV2(500, 1e8);
        srs = new SwapRouterSwapper(address(uniswapV3TestLib.swapRouter()));

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

        positionManager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(optionMarket), true);

        positionManager.updateWhitelistHandler(address(uniV3Handler), true);

        uniV3Handler.updateWhitelistedApps(address(positionManager), true);

        autoExercise = new AutoExerciseTimeBased();

        autoExercise.updateFeeTo(feeToAutoExercise);

        autoExercise.grantRole(keccak256("EXECUTOR"), autoExercisoor);

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

    function testLimitSellMarketFill() public {
        (address callOptionBuyer, uint256 callOptionBuyerPvk) = makeAddrAndKey("callOptionBuyer");
        (address putOptionBuyer, uint256 putOptionBuyerPvk) = makeAddrAndKey("putOptionBuyer");
        uint256 callOptionId = _purchaseOption(callOptionBuyer, true);
        uint256 putOptionId = _purchaseOption(putOptionBuyer, false);

        Order memory order = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: callOptionBuyer,
            validator: address(0),
            flags: 0x00000010,
            data: abi.encode(137046592384897080728, callOptionId, IOptionMarket(address(optionMarket)))
        });

        bytes32 digest = limitOrders.computeDigest(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(callOptionBuyerPvk, digest);

        Signature memory signature = Signature({r: r, s: s, v: v});

        vm.startPrank(callOptionBuyer);
        optionMarket.updateExerciseDelegate(address(limitOrders), true);
        vm.stopPrank();

        _updatePrice(true);
        _updatePrice(true);
        uint256 comission = limitOrders.exerciseOption(order, signature, _getExerciseParams(callOptionId));

        assertEqUint(comission, token0.balanceOf(address(this)));
        assertEq(limitOrders.isOrderCancelled(limitOrders.getOrderStructHash(order)), true);

        order = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: putOptionBuyer,
            validator: address(0),
            flags: 0x00000010,
            data: abi.encode(238904731596709170, putOptionId, IOptionMarket(address(optionMarket)))
        });

        digest = limitOrders.computeDigest(order);
        (v, r, s) = vm.sign(putOptionBuyerPvk, digest);
        signature = Signature({r: r, s: s, v: v});

        vm.startPrank(putOptionBuyer);
        optionMarket.updateExerciseDelegate(address(limitOrders), true);
        vm.stopPrank();

        _updatePrice(false);
        _updatePrice(false);
        _updatePrice(false);
        comission = limitOrders.exerciseOption(order, signature, _getExerciseParams(putOptionId));

        assertEqUint(comission, 0);
        assertEq(limitOrders.isOrderCancelled(limitOrders.getOrderStructHash(order)), true);
    }

    function testLimitBuyMarketFill() public {
        uint256 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            tickLowerCalls.getSqrtRatioAtTick(), tickUpperCalls.getSqrtRatioAtTick(), 5e18
        );
        uint256 _premiumAmountCalls = optionMarket.getPremiumAmount(
            false,
            block.timestamp + 20 minutes,
            optionMarket.getPricePerCallAssetViaTick(pool, tickUpperCalls),
            optionMarket.getCurrentPricePerCallAsset(pool),
            5e18
        );

        uint256 cost = _premiumAmountCalls + optionMarket.getFee(0, _premiumAmountCalls) + 10e18;

        (address optionBuyer, uint256 optionBuyerPvk) = makeAddrAndKey("optionBuyer");

        Order memory order = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: optionBuyer,
            validator: address(0),
            flags: 0x00000010,
            data: abi.encode(
                cost,
                20 minutes,
                IOptionMarket(address(optionMarket)),
                liquidity,
                1e18,
                10 minutes,
                tickLowerCalls,
                tickUpperCalls,
                true
            )
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(optionBuyerPvk, limitOrders.computeDigest(order));

        vm.startPrank(optionBuyer);
        token1.mint(optionBuyer, cost + 1e18);
        token1.approve(address(limitOrders), cost + 1e18);
        vm.stopPrank();

        IOptionMarket.OptionTicks[] memory opTicks = new IOptionMarket.OptionTicks[](1);
        opTicks[0] = IOptionMarket.OptionTicks({
            _handler: uniV3Handler,
            pool: pool,
            hook: hook,
            tickLower: tickLowerCalls,
            tickUpper: tickUpperCalls,
            liquidityToUse: liquidity
        });

        assertEqUint(limitOrders.purchaseOption(order, Signature({r: r, s: s, v: v}), opTicks), 1e18);
        assertEq(optionMarket.ownerOf(1), optionBuyer);
        assertEq(limitOrders.isOrderCancelled(limitOrders.getOrderStructHash(order)), true);
        assertEq(token1.balanceOf(optionBuyer), 10e18);

        liquidity = LiquidityAmounts.getLiquidityForAmount0(
            tickLowerPuts.getSqrtRatioAtTick(), tickUpperPuts.getSqrtRatioAtTick(), 10_000e18
        );

        uint256 _premiumAmountPuts = optionMarket.getPremiumAmount(
            true,
            block.timestamp + 20 minutes,
            optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts),
            optionMarket.getCurrentPricePerCallAsset(pool),
            (10_000e18 * 1e18) / optionMarket.getPricePerCallAssetViaTick(pool, tickLowerPuts)
        );

        cost = _premiumAmountPuts + optionMarket.getFee(0, _premiumAmountPuts);

        vm.startPrank(optionBuyer);
        token0.mint(optionBuyer, cost);
        token0.approve(address(limitOrders), cost);
        vm.stopPrank();

        opTicks[0] = IOptionMarket.OptionTicks({
            _handler: uniV3Handler,
            pool: pool,
            hook: hook,
            tickLower: tickLowerPuts,
            tickUpper: tickUpperPuts,
            liquidityToUse: liquidity
        });

        order = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: optionBuyer,
            validator: address(0),
            flags: 0x00000010,
            data: abi.encode(
                cost,
                20 minutes,
                IOptionMarket(address(optionMarket)),
                liquidity,
                0,
                10 minutes,
                tickLowerPuts,
                tickUpperPuts,
                false
            )
        });

        (v, r, s) = vm.sign(optionBuyerPvk, limitOrders.computeDigest(order));

        assertEqUint(limitOrders.purchaseOption(order, Signature({r: r, s: s, v: v}), opTicks), 0);
        assertEq(optionMarket.ownerOf(2), optionBuyer);
        assertEq(limitOrders.isOrderCancelled(limitOrders.getOrderStructHash(order)), true);
    }

    function testLimitSellOtc() public {
        (address optionSeller, uint256 optionSellerPvk) = makeAddrAndKey("optionSeller");
        uint256 optionId = _purchaseOption(optionSeller, true);

        uint256 offerPrice = 1e18;

        Order memory order = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: optionSeller,
            validator: address(0),
            flags: 0x00000001,
            data: abi.encode(
                offerPrice, optionId, IOptionMarket(address(optionMarket)), IERC20(address(token1)), address(0)
            )
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(optionSellerPvk, limitOrders.computeDigest(order));

        // Seller has to approve the limit orders contract to transfer the option
        vm.startPrank(optionSeller);
        optionMarket.updateExerciseDelegate(address(limitOrders), true);
        optionMarket.approve(address(limitOrders), optionId);
        vm.stopPrank();

        address optionBuyer = makeAddr("optionBuyer");
        token1.mint(optionBuyer, offerPrice);
        vm.startPrank(optionBuyer);
        token1.approve(address(limitOrders), offerPrice);

        limitOrders.fillOffer(order, Signature({r: r, s: s, v: v}));
        vm.stopPrank();
    }

    uint256 makerPvk;
    uint256 takerPvk;
    address maker;
    address taker;

    function testLimitBuyOtc() public {
        (maker, makerPvk) = makeAddrAndKey("maker");
        (taker, takerPvk) = makeAddrAndKey("taker");
        _purchaseOption(maker, true);

        uint256 offerPrice = 1e18;

        Order memory makerOrder = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: maker,
            validator: address(0),
            flags: 0x00000001,
            data: abi.encode(offerPrice, 1, IOptionMarket(address(optionMarket)), IERC20(address(token1)), address(0))
        });

        Order memory takerOrder = Order({
            createdAt: block.timestamp,
            deadline: block.timestamp + 20 minutes,
            maker: taker,
            validator: address(0),
            flags: 0x00000001,
            data: abi.encode(
                offerPrice,
                20 minutes,
                IOptionMarket(address(optionMarket)),
                // Liquidity of the option of the buyer
                LiquidityAmounts.getLiquidityForAmount1(
                    tickLowerCalls.getSqrtRatioAtTick(), tickUpperCalls.getSqrtRatioAtTick(), 5e18
                ),
                offerPrice / 2,
                10 minutes,
                tickLowerCalls,
                tickUpperCalls,
                true
            )
        });

        (uint8 vMaker, bytes32 rMaker, bytes32 sMaker) = vm.sign(makerPvk, limitOrders.computeDigest(makerOrder));

        (uint8 vTaker, bytes32 rTaker, bytes32 sTaker) = vm.sign(takerPvk, limitOrders.computeDigest(takerOrder));

        vm.startPrank(maker);
        // token1.mint(maker, offerPrice);
        optionMarket.approve(address(limitOrders), 1);
        vm.stopPrank();

        vm.startPrank(taker);
        token1.mint(taker, offerPrice + (offerPrice / 2));
        token1.approve(address(limitOrders), offerPrice + (offerPrice / 2));
        vm.stopPrank();

        limitOrders.matchOrders(
            makerOrder,
            takerOrder,
            Signature({r: rMaker, s: sMaker, v: vMaker}),
            Signature({r: rTaker, s: sTaker, v: vTaker})
        );

        assertEq(optionMarket.ownerOf(1), taker);
        assertEq(token1.balanceOf(maker), offerPrice);
        assertEq(token1.balanceOf(address(this)), offerPrice / 2);
        assertEq(limitOrders.isOrderCancelled(limitOrders.getOrderStructHash(makerOrder)), true);
        assertEq(limitOrders.isOrderCancelled(limitOrders.getOrderStructHash(takerOrder)), true);
    }

    function _getExerciseParams(uint256 optionId) private view returns (IOptionMarket.ExerciseOptionParams memory) {
        (,,,,, uint256 liquidityToUse) = optionMarket.opTickMap(optionId, 0);
        uint256[] memory liquidityToExercise = new uint256[](1);
        liquidityToExercise[0] = liquidityToUse;
        bytes[] memory swapDatas = new bytes[](1);
        swapDatas[0] = abi.encode(pool.fee(), 0);
        ISwapper[] memory swappers = new ISwapper[](1);
        swappers[0] = srs;

        return IOptionMarket.ExerciseOptionParams({
            optionId: optionId,
            swapper: swappers,
            swapData: swapDatas,
            liquidityToExercise: liquidityToExercise
        });
    }

    function _updatePrice(bool pump) internal {
        if (pump) {
            uniswapV3TestLib.performSwap(
                UniswapV3TestLib.SwapParamsStruct({
                    user: garbage,
                    pool: pool,
                    amountIn: 400000e18,
                    zeroForOne: true,
                    requireMint: true
                })
            );
        } else {
            uniswapV3TestLib.performSwap(
                UniswapV3TestLib.SwapParamsStruct({
                    user: garbage,
                    pool: pool,
                    amountIn: 250e18,
                    zeroForOne: false,
                    requireMint: true
                })
            );
        }
    }

    function _purchaseOption(address prankee, bool isCall) internal returns (uint256 tokenId) {
        vm.startPrank(prankee);

        if (isCall) {
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

            token1.mint(prankee, cost);
            token1.approve(address(optionMarket), cost);

            DopexV2OptionMarketV2.OptionTicks[] memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

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
        } else {
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
            token0.mint(prankee, cost);
            token0.approve(address(optionMarket), cost);

            DopexV2OptionMarketV2.OptionTicks[] memory opTicks = new DopexV2OptionMarketV2.OptionTicks[](1);

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
        }

        tokenId = optionMarket.optionIds();

        vm.stopPrank();
    }
}
