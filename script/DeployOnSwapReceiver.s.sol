// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {OnSwapReceiver} from "../src/swapper/OnSwapReceiver.sol";

contract DeployOnSwapReceiver is Script {
    function run() public {
        vm.startBroadcast();
        OnSwapReceiver swapper = new OnSwapReceiver();
        vm.stopBroadcast();
    }
}
