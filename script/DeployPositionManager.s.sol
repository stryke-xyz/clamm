// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";

contract DeployPositionManager is Script {
    function run() public {
        vm.startBroadcast();
        DopexV2PositionManager pm = new DopexV2PositionManager();
        console.log(address(pm));
        vm.stopBroadcast();
    }
}
// 