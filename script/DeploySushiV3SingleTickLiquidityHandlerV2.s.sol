// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SushiV3SingleTickLiquidityHandlerV2} from "../src/handlers/SushiV3SingleTickLiquidityHandlerV2.sol";

import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";
import {BoundedTTLHook_1Week} from "../src/handlers/hooks/BoundedTTLHook_1Week.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";



contract DeploySushiV3SingleTickLiquidityHandlerV2 is Script {
    function run() public {
        address factory = address(0);
        address swapRouter = address(0);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        SushiV3SingleTickLiquidityHandlerV2 sushiHandler = new SushiV3SingleTickLiquidityHandlerV2(
            factory, 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, swapRouter
        );

        sushiHandler.updateWhitelistedApps(address(0), true);
        BoundedTTLHook_0Day(address(0)).updateWhitelistedAppsStatus(address(sushiHandler), true);
        BoundedTTLHook_1Week(address(0)).updateWhitelistedAppsStatus(address(sushiHandler), true);
        DopexV2PositionManager(address(0)).updateWhitelistHandler(address(sushiHandler), true);

        console.log(address(sushiHandler));
        vm.stopBroadcast();
    }
}
