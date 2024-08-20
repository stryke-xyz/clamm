// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {LimitOrders} from "../src/periphery/limit-orders/LimitOrders.sol";

contract DeployLimitOrders is Script {
    function run() public {
        vm.startBroadcast();
        LimitOrders limitOrders = new LimitOrders();
        console.log(address(limitOrders));
        vm.stopBroadcast();
    }
}
