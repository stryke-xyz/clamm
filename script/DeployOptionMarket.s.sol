// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarket} from "../src/DopexV2OptionMarket.sol";

contract DeployOptionMarket is Script {
    function run() public {
        address optionPricing = 0x2b99e3D67dAD973c1B9747Da742B7E26c8Bdd67B;
        address pm = 0xE4bA6740aF4c666325D49B3112E4758371386aDc; // Change
        address dpFee = address(0);
        address callAsset = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        address putAsset = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address primePool = 0xC6F780497A95e246EB9449f5e4770916DCd6396A;

        vm.startBroadcast();
        DopexV2OptionMarket om = new DopexV2OptionMarket(
            pm,
            optionPricing,
            dpFee,
            callAsset,
            putAsset,
            primePool
        );
        console.log(address(om));

        uint256[] memory ttls = new uint256[](6);
        ttls[0] = 20 minutes;
        ttls[1] = 1 hours;
        ttls[2] = 2 hours;
        ttls[3] = 6 hours;
        ttls[4] = 12 hours;
        ttls[5] = 24 hours;

        uint256[] memory IVs = new uint256[](6);
        IVs[0] = 120;
        IVs[1] = 90;
        IVs[2] = 80;
        IVs[3] = 60;
        IVs[4] = 40;
        IVs[5] = 30;

        om.updateIVs(ttls, IVs);

        om.updateAddress(
            address(0),
            address(0),
            dpFee,
            optionPricing,
            msg.sender,
            true,
            primePool,
            true
        );
        vm.stopBroadcast();
    }
}
