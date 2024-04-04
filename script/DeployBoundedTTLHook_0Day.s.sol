// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";

contract DeployBoundedTTLHook_0Day is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        BoundedTTLHook_0Day hook = new BoundedTTLHook_0Day();

        console.log(address(hook));

        hook.updateWhitelistedAppsStatus(0x501B03BdB431154b8Df17BF1c00756E3a8F21744, true);
        hook.updateWhitelistedAppsStatus(0x550e7E236912DaA302F7d5D0d6e5D7b6EF191f04, true);
        hook.updateWhitelistedAppsStatus(0x4eed3A2b797Bf5630517EcCe2e31C1438A76bb92, true);

        vm.stopBroadcast();
    }
}
