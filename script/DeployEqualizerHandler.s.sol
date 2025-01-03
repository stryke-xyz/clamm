// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {EqualizerV3SingleTickLiquidityHandlerV2} from "../src/handlers/EqualizerV3SingleTickLiquidityHandlerV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";
import {BoundedTTLHook_1Week} from "../src/handlers/hooks/BoundedTTLHook_1Week.sol";

contract DeploySushiV3SingleTickLiquidityHandlerV2 is Script {
    function run() public {
        address factory = address(0);
        address swapRouter = address(0);
        DopexV2PositionManager positionManager = DopexV2PositionManager(address(0));
        BoundedTTLHook_0Day zeroDayHook = BoundedTTLHook_0Day(address(0));
        BoundedTTLHook_0Day weeklyHook = BoundedTTLHook_0Day(address(0));

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        EqualizerV3SingleTickLiquidityHandlerV2 handler =
            new EqualizerV3SingleTickLiquidityHandlerV2(factory, swapRouter);

        positionManager.updateWhitelistHandler(address(handler), true);
        handler.updateWhitelistedApps(address(positionManager), true);
        zeroDayHook.updateWhitelistedAppsStatus(address(handler), true);
        weeklyHook.updateWhitelistedAppsStatus(address(handler), true);

        console.log(address(handler));
        vm.stopBroadcast();
    }
}
