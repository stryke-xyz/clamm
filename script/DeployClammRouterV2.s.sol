// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ClammRouterV2} from "../src/router/ClammRouterV2.sol";

contract DeployClammRouterV2 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ClammRouterV2 router = new ClammRouterV2();
        console.log(address(router));
        vm.stopBroadcast();
    }
}
