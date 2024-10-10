// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract DeployFeeStrategy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        DopexV2ClammFeeStrategyV2 feeStrategy = new DopexV2ClammFeeStrategyV2();

        console.log(address(feeStrategy));

        vm.stopBroadcast();
    }
}
