// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2ClammFeeStrategy} from "../src/pricing/fees/DopexV2ClammFeeStrategy.sol";

contract DeployFeeStrategy is Script {
    function run() public {
        vm.startBroadcast();
        DopexV2ClammFeeStrategy feeStrategy = new DopexV2ClammFeeStrategy();
        console.log(address(feeStrategy));
        vm.stopBroadcast();
    }
}
