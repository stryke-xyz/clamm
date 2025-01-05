// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {UniswapV3TestLib} from "../utils/uniswap-v3/UniswapV3TestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {IOptionPricingV2} from "../../src/pricing/IOptionPricingV2.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";
import {ISwapper} from "../../src/interfaces/ISwapper.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";

import {OptionPricingV2} from "../../src/pricing/OptionPricingV2.sol";
import {DopexV2ClammFeeStrategyV2} from "../../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";
import {SwapRouterSwapper} from "../../src/swapper/SwapRouterSwapper.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {UniswapV3SingleTickLiquidityHarnessV2} from "../harness/UniswapV3SingleTickLiquidityHarnessV2.sol";
import {UniswapV3SingleTickLiquidityHandlerV2} from "../../src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol";
import {DopexV2OptionMarketV2} from "../../src/DopexV2OptionMarketV2.sol";
import {OpenSettlementV2} from "../../src/periphery/OpenSettlementV2.sol";

contract OpenSettlementV2Tests is Test {
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
    OpenSettlementV2 openSettlement;

    function setUp() public {
        ETH = address(new ERC20Mock());
        LUSD = address(new ERC20Mock());

        uniswapV3TestLib = new UniswapV3TestLib();
        pool = IUniswapV3Pool(uniswapV3TestLib.deployUniswapV3PoolAndInitializePrice(ETH, LUSD, fee, initSqrtPriceX96));

        token0 = ERC20Mock(pool.token0());
        token1 = ERC20Mock(pool.token1());

        positionManager = new DopexV2PositionManager();

        openSettlement = new OpenSettlementV2();

        openSettlement.grantRole(openSettlement.SETTLER_ROLE(), address(bot));

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
            feeCollector,
            address(0),
            address(feeStrategy),
            address(op),
            address(openSettlement),
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

        positionManager.updateWhitelistHandlerWithApp(address(uniV3Handler), address(optionMarket), true);

        positionManager.updateWhitelistHandler(address(uniV3Handler), true);

        uniV3Handler.updateWhitelistedApps(address(positionManager), true);

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

    // Settle after expiry
    // Ensure profits and comissions are transfered
    // test roles

    function testRoles() public {
        IOptionMarket.SettleOptionParams memory emptyParams;
        vm.prank(alice);

        vm.expectRevert(
            "AccessControl: account 0x328809bc894f92807417d2dad6b7c998c1afdac6 is missing role 0x6666bf5bfee463d10a7fc50448047f8a53b7762d7e28fbc5c643182785f3fd3f"
        );
        openSettlement.openSettle(IOptionMarket(address(optionMarket)), 0, emptyParams, address(0));

        vm.prank(bot);
        vm.expectRevert(abi.encodeWithSelector(0xceea21b6));
        openSettlement.openSettle(IOptionMarket(address(optionMarket)), 0, emptyParams, address(0));
    }

    function testOpenSettlementCallITM() public {
        uint256 callOptionId = _purchaseOption(alice, true);

        _updatePrice(true);
        _updatePrice(true);
        _updatePrice(true);

        assertEq(token0.balanceOf(bot), 0);
        assertEq(token0.balanceOf(alice), 2530);

        IOptionMarket.SettleOptionParams memory settleParams = _getSettleParams(callOptionId);
        vm.warp(block.timestamp + 21 minutes);
        vm.startPrank(bot);
        openSettlement.openSettle(IOptionMarket(address(optionMarket)), callOptionId, settleParams, bot);

        assertEq(token0.balanceOf(bot), 9720511920421103301);
        assertEq(token0.balanceOf(alice), 962330680121689229413);
        assertEq(token0.balanceOf(address(openSettlement)), 0);
    }

    function testOpenSettlementPutITM() public {
        uint256 putOptionId = _purchaseOption(alice, false);

        _updatePrice(false);
        _updatePrice(false);
        _updatePrice(false);

        assertEq(token1.balanceOf(bot), 0);
        assertEq(token1.balanceOf(alice), 0);

        IOptionMarket.SettleOptionParams memory settleParams = _getSettleParams(putOptionId);
        vm.warp(block.timestamp + 21 minutes);
        vm.startPrank(bot);
        openSettlement.openSettle(IOptionMarket(address(optionMarket)), putOptionId, settleParams, bot);

        assertEq(token1.balanceOf(bot), 6468823822773321);
        assertEq(token1.balanceOf(alice), 640413558454558797);
        assertEq(token1.balanceOf(address(openSettlement)), 0);
    }

    function testOpenSettlementTOM() public {
        uint256 callOptionId = _purchaseOption(alice, true);
        uint256 putOptionId = _purchaseOption(bob, false);

        assertEq(token1.balanceOf(address(optionMarket)), 5000000000000000000);
        assertEq(token0.balanceOf(address(optionMarket)), 10000000000000000000000);

        IOptionMarket.SettleOptionParams memory settleParams0 = _getSettleParams(callOptionId);
        IOptionMarket.SettleOptionParams memory settleParams1 = _getSettleParams(putOptionId);

        vm.warp(block.timestamp + 21 minutes);
        vm.startPrank(bot);
        openSettlement.openSettle(IOptionMarket(address(optionMarket)), callOptionId, settleParams0, bot);
        openSettlement.openSettle(IOptionMarket(address(optionMarket)), putOptionId, settleParams1, bot);
        vm.stopPrank();

        assertEq(token1.balanceOf(address(optionMarket)), 1);
        assertEq(token0.balanceOf(address(optionMarket)), 1);
    }

    function testUpdateComission() public {
        assertEq(openSettlement.commissionPercentage(), 1e4);
        openSettlement.updateComission(1e10);
        assertEq(openSettlement.commissionPercentage(), 1e10);
    }

    function _getSettleParams(uint256 optionId) private view returns (IOptionMarket.SettleOptionParams memory) {
        (,,,,, uint256 liquidityToUse) = optionMarket.opTickMap(optionId, 0);
        uint256[] memory liquidityToSettle = new uint256[](1);
        liquidityToSettle[0] = liquidityToUse;

        bytes[] memory swapDatas = new bytes[](1);
        swapDatas[0] = abi.encode(pool.fee(), 0);
        ISwapper[] memory swappers = new ISwapper[](1);
        swappers[0] = srs;

        return IOptionMarket.SettleOptionParams({
            optionId: optionId,
            swapper: swappers,
            swapData: swapDatas,
            liquidityToSettle: liquidityToSettle
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
