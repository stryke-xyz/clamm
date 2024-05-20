// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {OptionPricingLinearV2_1} from "../src/pricing/OptionPricingLinearV2_1.sol";

contract DeployOptionPricingLinearV2_1 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        OptionPricingLinearV2_1 opl = new OptionPricingLinearV2_1(10000000,0x50E04E222Fc1be96E94E86AcF1136cB0E97E1d40);
        console.log(address(opl));

        // Set IV
        uint256[] memory ttls = new uint256[](6);
        uint256[] memory ttlIV = new uint256[](6);
        ttls[0] = 3600;
        ttls[1] = 7200;
        ttls[2] = 21600;
        ttls[3] = 43200;
        ttls[4] = 86400;
        ttls[5] = 604800;

        ttlIV[0] = 52;
        ttlIV[1] = 52;
        ttlIV[2] = 52;
        ttlIV[3] = 52;
        ttlIV[4] = 52;
        ttlIV[5] = 52;

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

        volatilityMultipliers[0] = 1000;
        volatilityMultipliers[1] = 1000;
        volatilityMultipliers[2] = 1000;
        volatilityMultipliers[3] = 1000;
        volatilityMultipliers[4] = 1000;
        volatilityMultipliers[5] = 1000;

        opl.updateVolatilityMultiplier(volatilityMultipliers, ttls);

        // Set XSYK Balance requirement and discounts
        uint256[] memory _xsykBalances = new uint256[](3);
        uint256[] memory _discounts = new uint256[](3);

        _xsykBalances[0] = 100;
        _xsykBalances[1] = 1000;
        _xsykBalances[2] = 10000;

        _discounts[0] = 1000;
        _discounts[1] = 2000;
        _discounts[2] = 3000;

        opl.setXSYKBalancesAndDiscounts(_xsykBalances, _discounts);

        vm.stopBroadcast();
    }
}
