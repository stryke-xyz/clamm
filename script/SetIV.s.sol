// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {OptionPricingLinearV2_1} from "../src/pricing/OptionPricingLinearV2_1.sol";

contract SetIV is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        OptionPricingLinearV2_1 opl = OptionPricingLinearV2_1(address(0));
        
        uint256[] memory ttls = new uint256[](6);
        uint256[] memory ttlIV = new uint256[](6);

        ttls[0] = 3600;
        ttls[1] = 7200;
        ttls[2] = 21600;
        ttls[3] = 43200;
        ttls[4] = 86400;
        ttls[5] = 604800;

        ttlIV[0] = 70;
        ttlIV[1] = 70;
        ttlIV[2] = 70;
        ttlIV[3] = 70;
        ttlIV[4] = 70;
        ttlIV[5] = 100;

        opl.updateIVs(ttls, ttlIV);

        // Set Volatility Offset
        uint256[] memory volatilityOffsets = new uint256[](6);
        volatilityOffsets[0] = 10000;
        volatilityOffsets[1] = 10000;
        volatilityOffsets[2] = 10000;
        volatilityOffsets[3] = 10000;
        volatilityOffsets[4] = 10000;
        volatilityOffsets[5] = 10000;

        opl.updateVolatilityOffset(volatilityOffsets, ttls);

        // Set Volatility Multiplier
        uint256[] memory volatilityMultipliers = new uint256[](6);

        volatilityMultipliers[0] = 400;
        volatilityMultipliers[1] = 400;
        volatilityMultipliers[2] = 400;
        volatilityMultipliers[3] = 400;
        volatilityMultipliers[4] = 400;
        volatilityMultipliers[5] = 1000;

        opl.updateVolatilityMultiplier(volatilityMultipliers, ttls);

        vm.stopBroadcast();
    }
}
