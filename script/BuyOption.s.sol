// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarket} from "../src/DopexV2OptionMarket.sol";
import {IHandler} from "../src/interfaces/IHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract BuyOption is Script {
    function run() public {
        address op = 0x7d6BA9528A1449Fa944D81Ea16089D0db01F2A20;
        vm.startBroadcast();
        DopexV2OptionMarket.OptionTicks[]
            memory opTicks = new DopexV2OptionMarket.OptionTicks[](1);

        opTicks[0] = DopexV2OptionMarket.OptionTicks({
            _handler: IHandler(0xBdAd87fFcB972E55A94C0aDca42E2c21441070A1),
            pool: IUniswapV3Pool(0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443),
            tickLower: -200820,
            tickUpper: -200810,
            liquidityToUse: 436067757110940
        });

        ERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1).approve(
            op,
            type(uint256).max
        );

        DopexV2OptionMarket(op).mintOption(
            DopexV2OptionMarket.OptionParams({
                optionTicks: opTicks,
                tickLower: -200820,
                tickUpper: -200810,
                ttl: 24 hours,
                isCall: true,
                maxCostAllowance: 23108495619576
            })
        );

        vm.stopBroadcast();
    }
}
