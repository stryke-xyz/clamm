// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";
import {BoundedTTLHook_1Week} from "../src/handlers/hooks/BoundedTTLHook_1Week.sol";

contract WhitelistHandlerWithApp is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // address pm = address(0);
        address om1 = address(0);
        address om2 = address(0);
        // address handler = address(0);
        address hook0 = address(0);
        address hook1 = address(0);

        vm.startBroadcast(deployerPrivateKey);

            // BoundedTTLHook_1Week(hook0).updateWhitelistedAppsStatus(om1, true);
            // BoundedTTLHook_1Week(hook1).updateWhitelistedAppsStatus(om1, true);

            BoundedTTLHook_1Week(hook0).updateWhitelistedAppsStatus(om2, true);
            // BoundedTTLHook_1Week(hook1).updateWhitelistedAppsStatus(om2, true);

        // DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(handler, (om), true);

        vm.stopBroadcast();
    }
}
