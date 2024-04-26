// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ClammRouter} from "../src/router/ClammRouter.sol";

contract DeployClammRouter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        ClammRouter router = new ClammRouter();
        console.log(address(router));
        vm.stopBroadcast();
    }
}
