// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";

contract DeployOptionMarketV2 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address optionPricing = 0x0Fd9874A8902772c3573C11E8162F78cC96940B5;
        address pm = 0xE4bA6740aF4c666325D49B3112E4758371386aDc;
        address uniV3Handler = 0x29BbF7EbB9C5146c98851e76A5529985E4052116;
        address dpFee = 0xC808AcB06077174333b31Ae123C33c6559730035;
        address feeTo = 0x5674Ce0Dbb2B5973aB768fB40938524da927A459;
        address callAsset = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        address putAsset = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        address primePool = 0xb0f6cA40411360c03d41C5fFc5F179b8403CdcF8;

        vm.startBroadcast(deployerPrivateKey);
        DopexV2OptionMarketV2 om = new DopexV2OptionMarketV2(pm, optionPricing, dpFee, callAsset, putAsset, primePool);
        console.log(address(om));

        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(uniV3Handler, address(om), true);

        om.updateAddress(feeTo, address(0), dpFee, optionPricing, msg.sender, true, primePool, true);
        vm.stopBroadcast();
    }
}
