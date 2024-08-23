// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {MultiLimitOrdersExecutor} from "../src/periphery/limit-orders/MultiLimitOrdersExecutor.sol";

contract DeployMultiLimitOrdersExecutor is Script {
    function run() public {
        vm.startBroadcast();
        MultiLimitOrdersExecutor limitOrders = new MultiLimitOrdersExecutor(0x662026937ae0dc84C0Ff32F8f7035d777A4f3CeB);
        console.log(address(limitOrders));
        vm.stopBroadcast();
    }
}
