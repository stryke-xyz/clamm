// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SushiV3SingleTickLiquidityHandlerV2} from "../src/handlers/SushiV3SingleTickLiquidityHandlerV2.sol";

contract DeploySushiV3SingleTickLiquidityHandlerV2 is Script {
    function run() public {
        address factory = 0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e;
        address swapRouter = 0x8A21F6768C1f8075791D08546Dadf6daA0bE820c;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        SushiV3SingleTickLiquidityHandlerV2 sushiHandler = new SushiV3SingleTickLiquidityHandlerV2(
            factory, 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, swapRouter
        );
        console.log(address(sushiHandler));
        vm.stopBroadcast();
    }
}
