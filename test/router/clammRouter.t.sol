// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdAssertions.sol";

import {ClammRouter} from "../../src/router/ClammRouter.sol";
import {UniswapV3SingleTickLiquidityHandlerV2} from "../../src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IOptionMarket} from "../../src/interfaces/IOptionMarket.sol";

contract ClammRouterTest is Test {
    ClammRouter router;
    UniswapV3SingleTickLiquidityHandlerV2 handler;

    string internal constant ARBITRUM_RPC_URL = "https://arbitrum-mainnet.infura.io/v3/c088bb4e4cc643d5a0d3bb668a400685";
    uint256 internal constant BLOCK_NUM = 204418426; // 2024/04/24

    address trader = makeAddr("trader"); // option buyer

    function setUp() public {
        uint256 forkId = vm.createFork(ARBITRUM_RPC_URL, BLOCK_NUM);
        vm.selectFork(forkId);

        router = new ClammRouter();
        handler = UniswapV3SingleTickLiquidityHandlerV2(0x29BbF7EbB9C5146c98851e76A5529985E4052116);
    }

    function test_mintOption() public {
        vm.startPrank(0xC0F98702913c57aDe5632323cD9FA486c61Fd6F1);

        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(address(router), 1 ether);

        IOptionMarket.OptionTicks[] memory opTicks = new IOptionMarket.OptionTicks[](1);

        opTicks[0] = IOptionMarket.OptionTicks({
            _handler: handler,
            pool: IUniswapV3Pool(0xC6962004f452bE9203591991D15f6b388e09E8D0),
            hook: address(0x0000000000000000000000000000000000000000),
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
            maxCostAllowance: 0.1 ether
        });

        address optionMarket = address(0x501B03BdB431154b8Df17BF1c00756E3a8F21744);
        address receiver = address(0xC0F98702913c57aDe5632323cD9FA486c61Fd6F1);
        uint256 frontendId = 0;
        uint256 referalId = 0;

        // assert 0 balance
        assertEq(IOptionMarket(optionMarket).balanceOf(receiver), 0);
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);

        assertEq(IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(router)), 0);
        uint256 userOldBalance = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(receiver);

        router.mintOption(_params, optionMarket, receiver, frontendId, referalId);

        vm.stopPrank();

        assertEq(IOptionMarket(optionMarket).balanceOf(receiver), 1);
        assertEq(IOptionMarket(optionMarket).balanceOf(address(router)), 0);

        assertEq(IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(address(router)), 0);
        assertLt(IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).balanceOf(receiver), userOldBalance);
    }
}
