// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdAssertions.sol";

import {OptionPricingLinearV2_1} from "../../src/pricing/OptionPricingLinearV2_1.sol";
import {ClammRouter} from "../../src/router/ClammRouter.sol";
import {DopexV2OptionMarket} from "../../src/DopexV2OptionMarket.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";

contract OptionPricingLinearV2_1_Test is Test {
    OptionPricingLinearV2_1 pricing;
    ClammRouter router;
    DopexV2OptionMarket dopexV2OptionMarket;

    IHandler handler;
    IERC20 xsyk;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 204418426);

        pricing = new OptionPricingLinearV2_1(10000000, 0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40);
        router = new ClammRouter();
        handler = IHandler(0x29BbF7EbB9C5146c98851e76A5529985E4052116);
        xsyk = IERC20(0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40);
        dopexV2OptionMarket = DopexV2OptionMarket(0x501B03BdB431154b8Df17BF1c00756E3a8F21744);
    }

    function test_Pricing() public {
        vm.startPrank(0xDe9E9238D949df8bf37216406aB8133440edC235);

        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(address(router), 1 ether);

        IOptionMarket.OptionTicks[] memory opTicks = new IOptionMarket.OptionTicks[](1);

        opTicks[0] = IOptionMarket.OptionTicks({
            _handler: handler,
            pool: IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            hook: 0x0000000000000000000000000000000000000000,
            tickLower: -195360,
            tickUpper: -195350,
            liquidityToUse: 467541131811138364
        });

        IOptionMarket.OptionParams memory _params = IOptionMarket.OptionParams({
            optionTicks: opTicks,
            tickLower: -195360,
            tickUpper: -195350,
            ttl: 3600,
            isCall: true,
            maxCostAllowance: 0.01 ether
        });

        address optionMarket = address(0x501B03BdB431154b8Df17BF1c00756E3a8F21744);
        address receiver = address(0xDe9E9238D949df8bf37216406aB8133440edC235);
        bytes32 frontendId = 0;
        bytes32 referalId = 0;

        router.mintOption(_params, optionMarket, receiver, frontendId, referalId);

        vm.stopPrank();

        vm.startPrank(0x880C3cdCA73254D466f9c716248339dE88e4a97D);

        dopexV2OptionMarket.updateAddress(
            0x5674Ce0Dbb2B5973aB768fB40938524da927A459,
            0x0000000000000000000000000000000000000000,
            0xdcb12fCBf30B6824ef852f65D529038fAA1142bD,
            address(pricing),
            0x0000000000000000000000000000000000000000,
            false,
            0xC6962004f452bE9203591991D15f6b388e09E8D0,
            true
        );
        vm.stopPrank();
        uint256[] memory _xSykBalances = new uint256[](3);
        uint256[] memory _discounts = new uint256[](3);

        _xSykBalances[0] = 100;
        _xSykBalances[1] = 1000;
        _xSykBalances[2] = 10000;

        _discounts[0] = 1000;
        _discounts[1] = 2000;
        _discounts[2] = 3000;

        pricing.setXSykBalancesAndDiscounts(_xSykBalances, _discounts);
        pricing.updateIVSetter(address(this), true);

        uint256[] memory ttls = new uint256[](1);
        uint256[] memory ttlIV = new uint256[](1);
        uint256[] memory volatilityOffsets = new uint256[](1);
        uint256[] memory volatilityMultipliers = new uint256[](1);

        ttls[0] = 3600;
        ttlIV[0] = 52;
        volatilityOffsets[0] = 10000;
        volatilityMultipliers[0] = 1000;

        pricing.updateIVs(ttls, ttlIV);
        pricing.updateVolatilityOffset(volatilityOffsets, ttls);
        pricing.updateVolatilityMultiplier(volatilityMultipliers, ttls);

        uint256 initalVol = pricing.getVolatility(3100, 3000, 60, 3600);
        assertEq(pricing.getVolatility(3100, 3000, 60, 3600), initalVol);

        // buy put option 3162 and test new pricing contract with discount

        deal(0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40, 0xDe9E9238D949df8bf37216406aB8133440edC235, 10001);

        vm.startPrank(0xDe9E9238D949df8bf37216406aB8133440edC235, 0xDe9E9238D949df8bf37216406aB8133440edC235);

        IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).approve(address(router), 1 ether);
        handler = IHandler(0x9ae336B61D7d2e19a47607f163A3fB0e46306b7b);

        opTicks[0] = IOptionMarket.OptionTicks({
            _handler: handler,
            pool: IUniswapV3Pool(0xd9e2a1a61B6E61b275cEc326465d417e52C1b95c),
            hook: 0x8c30c7F03421D2C9A0354e93c23014BF6C465a79,
            tickLower: -195740,
            tickUpper: -195730,
            liquidityToUse: 10617918712701
        });

        _params = IOptionMarket.OptionParams({
            optionTicks: opTicks,
            tickLower: -195740,
            tickUpper: -195730,
            ttl: 3600,
            isCall: false,
            maxCostAllowance: 1e7
        });

        frontendId = bytes32("1");

        router.mintOption(_params, optionMarket, receiver, frontendId, referalId);

        vm.stopPrank();

        // assert discount is applied on discount
        deal(0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38, 101);

        assertEq(pricing.getVolatility(3100, 3000, 60, 3600), initalVol * 90 / 100);

        deal(0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38, 1001);

        assertEq(pricing.getVolatility(3100, 3000, 60, 3600), initalVol * 80 / 100);

        deal(0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40, 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38, 10001);

        assertEq(pricing.getVolatility(3100, 3000, 60, 3600), initalVol * 70 / 100);
    }
}
