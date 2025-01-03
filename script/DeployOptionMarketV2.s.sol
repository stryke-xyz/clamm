// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract DeployOptionMarketV2 is Script {
    function run() public {
        address optionPricing = address(0);

        address pm = address(0);

        address dpFee = address(0);

        address callAsset = address(0);

        address putAsset = address(0);

        address primePool = address(0);

        address handler = address(0);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        DopexV2OptionMarketV2 om = new DopexV2OptionMarketV2(pm, optionPricing, dpFee, callAsset, putAsset, primePool);

        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(handler, address(om), true);
        DopexV2ClammFeeStrategyV2(dpFee).registerOptionMarket(address(om), 340000);

        om.updateAddress(address(0), address(0), dpFee, optionPricing, address(0), true, primePool, true);

        vm.stopBroadcast();
    }
}
