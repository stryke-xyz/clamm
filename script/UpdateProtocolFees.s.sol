// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract UpdateProtocolFees is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // address optionMarket0 = address(0);
        // address optionMarket1 = address(0);
        // address feeStrategy = address(0);
        // address newFees = 150000;

        vm.startBroadcast(deployerPrivateKey);

        DopexV2ClammFeeStrategyV2(address(0)).updateFees(0x9d3828e89Fadc4DEc77758988b388435Fe0f8DCa, 150000);
        DopexV2ClammFeeStrategyV2(address(0)).updateFees(0x342e4068bA07bbCcBDDE503b2451FAa3D3C0278B, 150000);

        vm.stopBroadcast();
    }
}
