// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";
import {BoundedTTLHook_1Week} from "../src/handlers/hooks/BoundedTTLHook_1Week.sol";

contract DeployOptionMarketV2 is Script {
    function run() public {
        address optionPricing = address(0);
        address pm = address(0);
        address dpFee = 0x0189D0E3965FCa86bCA5659eBDbFe8dCc9aa36B0;
        address callAsset = 0x4200000000000000000000000000000000000006;
        address putAsset = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address primePool = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        address handler = 0xa51175f9076b2535003ac146921485083ab3a63c;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        DopexV2OptionMarketV2 om = new DopexV2OptionMarketV2(pm, optionPricing, dpFee, callAsset, putAsset, primePool);

        console.log(address(om));

        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(handler, address(om), true);
        DopexV2PositionManager(pm).updateWhitelistHandler(handler, true);
        BoundedTTLHook_1Week(address(0)).updateWhitelistedAppsStatus(address(om), true);
        BoundedTTLHook_0Day(address(0)).updateWhitelistedAppsStatus(address(om), true);

        vm.stopBroadcast();
    }
}
