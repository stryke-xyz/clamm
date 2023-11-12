// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarket} from "../src/DopexV2OptionMarket.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";

contract DeployOptionMarket is Script {
    function run() public {
        address optionPricing = 0x2b99e3D67dAD973c1B9747Da742B7E26c8Bdd67B;
        address pm = 0xE4bA6740aF4c666325D49B3112E4758371386aDc;
        address uniV3Handler = 0xe11d346757d052214686bCbC860C94363AfB4a9A;
        address dpFee = address(0);
        address callAsset = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        address putAsset = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        address primePool = 0xcDa53B1F66614552F834cEeF361A8D12a0B8DaD8;

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

        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(
            uniV3Handler,
            address(om),
            true
        );

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
