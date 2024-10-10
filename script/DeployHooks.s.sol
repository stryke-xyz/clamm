// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";
import {BoundedTTLHook_1Week} from "../src/handlers/hooks/BoundedTTLHook_1Week.sol";

contract DeployHooks is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        BoundedTTLHook_0Day zeroDayHook = new BoundedTTLHook_0Day();
        BoundedTTLHook_1Week weeklyHook = new BoundedTTLHook_1Week();

        console.log("Zero Day Hook", address(zeroDayHook));

        console.log("Weekly Hook", address(weeklyHook));

        vm.stopBroadcast();
    }
}
