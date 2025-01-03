// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract UpdateAddressesOptionMarket is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // address settler = ;
        // address om = ;

        // DopexV2OptionMarketV2 market = DopexV2OptionMarketV2(om);

        // market.updateAddress(
        //     ,
        //     address(0),
        //     address(market.dpFee()),
        //     address(market.optionPricing()),
        //     settler,
        //     true,
        //     address(market.primePool()),
        //     true
        // );

        vm.stopBroadcast();
    }
}
