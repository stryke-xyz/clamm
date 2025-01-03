// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract RegisterOptionMarketFees is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address optionMarket = address(0);
        address feeStrategy = address(0);

        vm.startBroadcast(deployerPrivateKey);

        DopexV2ClammFeeStrategyV2(feeStrategy).registerOptionMarket(optionMarket, 34000);

        vm.stopBroadcast();
    }
}
