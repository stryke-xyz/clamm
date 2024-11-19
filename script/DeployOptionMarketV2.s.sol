// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {BoundedTTLHook_0Day} from "../src/handlers/hooks/BoundedTTLHook_0Day.sol";
import {BoundedTTLHook_1Week} from "../src/handlers/hooks/BoundedTTLHook_1Week.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract DeployOptionMarketV2 is Script {
    function run() public {
        address optionPricing = 0x498be9B5af6D03398Edf997C8D811De5192dC85C;
        address pm = 0x99fF939Ef399f5569d57868d43118e6586F574d9;
        address dpFee = 0x0189D0E3965FCa86bCA5659eBDbFe8dCc9aa36B0;
        address callAsset = 0x4200000000000000000000000000000000000006;
        address putAsset = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        address primePool = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        address handler = address(0xa51175F9076B2535003AC146921485083aB3A63c);
        address oneWeekHook = 0x4e83CD2C50d270C4Bf264C4C16836047173C08c0;
        address zeroDayHook = 0x853ca947d0AD6408aC4f57C507dFcaE151240D2D;
        address settler = 0x3f4BC1FFADb1435F19909D31588F4ce12bC0e452;
        address feeTo = 0x5674Ce0Dbb2B5973aB768fB40938524da927A459;
        address dpFee = 0x0189D0E3965FCa86bCA5659eBDbFe8dCc9aa36B0;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        DopexV2OptionMarketV2 om = new DopexV2OptionMarketV2(pm, optionPricing, dpFee, callAsset, putAsset, primePool);

        om.updateAddress(feeTo, address(0), _dpFee, optionPricing, settler, true, primePool, true);

        DopexV2ClammFeeStrategyV2(dpFee).registeredOptionMarkets(address(om), true);


        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(handler, address(om), true);
        DopexV2PositionManager(pm).updateWhitelistHandler(handler, true);
        BoundedTTLHook_1Week(0x853ca947d0AD6408aC4f57C507dFcaE151240D2D).updateWhitelistedAppsStatus(address(om), true);
        BoundedTTLHook_0Day(0x4e83CD2C50d270C4Bf264C4C16836047173C08c0).updateWhitelistedAppsStatus(address(om), true);

        vm.stopBroadcast();
    }
}
