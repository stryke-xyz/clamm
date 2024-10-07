// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {LimitOrders} from "../src/periphery/limit-orders/LimitOrders.sol";
import {MultiLimitOrdersExecutor} from "../src/periphery/limit-orders/MultiLimitOrdersExecutor.sol";

contract DeployLimitOrders is Script {
    function run() public {
        vm.startBroadcast();
        // LimitOrders limitOrders = new LimitOrders();
        // MultiLimitOrdersExecutor mloe = new MultiLimitOrdersExecutor();
        // console.log("limit orders", address(limitOrders));
        // console.log("mloe", address(mloe));
        vm.stopBroadcast();
    }
}
