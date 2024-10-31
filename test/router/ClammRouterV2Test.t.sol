// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdAssertions.sol";

import {ClammRouterV2} from "../../src/router/ClammRouterV2.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";
import {IERC6909} from "../../src/interfaces/IERC6909.sol";

import {UniswapV3SingleTickLiquidityHandlerV2} from "../../src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol";

contract ClammRouterV2Test is Test {
    ClammRouterV2 router;
    IHandler handler;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 204418426);

        router = new ClammRouterV2();
        handler = IHandler(0x29BbF7EbB9C5146c98851e76A5529985E4052116);
        router.setDopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc);
    }

    function test_mintOption() public {
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

        // assert 0 balance
        uint256 optionBalance = IOptionMarket(optionMarket).balanceOf(receiver);
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);

        assertEq(IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(router)), 0);
        uint256 oldBalance = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(receiver);

        router.mintOption(_params, optionMarket, receiver, frontendId, referalId);

        vm.stopPrank();

        assertEq(IOptionMarket(optionMarket).balanceOf(receiver), optionBalance + 1);
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);

        assertEq(IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(router)), 0);
        assertEq(oldBalance - IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(receiver), 5466894058529321);

        // buy put option 3162

        vm.startPrank(0xDe9E9238D949df8bf37216406aB8133440edC235);

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

        // assert balance
        assertEq(IOptionMarket(optionMarket).balanceOf(receiver), optionBalance + 1);
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);

        assertEq(IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).balanceOf(address(router)), 0);

        oldBalance = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).balanceOf(receiver);

        router.mintOption(_params, optionMarket, receiver, frontendId, referalId);

        vm.stopPrank();

        assertEq(IOptionMarket(optionMarket).balanceOf(receiver), optionBalance + 2);
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);

        assertEq(IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).balanceOf(address(router)), 0);
        assertEq(oldBalance - IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831).balanceOf(receiver), 617);
    }

    function testFail_mintOption() public {
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
            maxCostAllowance: 0.000001 ether
        });

        address optionMarket = address(0x501B03BdB431154b8Df17BF1c00756E3a8F21744);
        address receiver = address(0xDe9E9238D949df8bf37216406aB8133440edC235);
        bytes32 frontendId = 0;
        bytes32 referalId = 0;

        // assert 0 balance
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);
        assertEq(IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(router)), 0);

        router.mintOption(_params, optionMarket, receiver, frontendId, referalId);

        vm.stopPrank();
    }

    function test_mintPosition() public {
        vm.startPrank(0xDe9E9238D949df8bf37216406aB8133440edC235);

        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(address(router), 1 ether);

        bytes memory data = abi.encode(
            UniswapV3SingleTickLiquidityHandlerV2.MintPositionParams({
                pool: IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
                hook: 0x0000000000000000000000000000000000000000,
                tickLower: -195360,
                tickUpper: -195350,
                liquidity: 467541131811138
            })
        );

        address receiver = address(0xDe9E9238D949df8bf37216406aB8133440edC235);
        bytes32 frontendId = 0;
        bytes32 referalId = 0;

        uint256 amount = router.mintPosition(
            IHandler(0x29BbF7EbB9C5146c98851e76A5529985E4052116), data, receiver, frontendId, referalId
        );

        assertEq(
            amount,
            IERC6909(0x29BbF7EbB9C5146c98851e76A5529985E4052116).balanceOf(
                receiver, 69065842648392217392428702702373800087305271312427941318721945433946963591500
            )
        );

        assertEq(
            0,
            IERC6909(0x29BbF7EbB9C5146c98851e76A5529985E4052116).balanceOf(
                address(router), 69065842648392217392428702702373800087305271312427941318721945433946963591500
            )
        );
        vm.stopPrank();
    }
}
