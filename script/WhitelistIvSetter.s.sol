// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {OptionPricingLinearV2_1} from "../src/pricing/OptionPricingLinearV2_1.sol";

contract WhitelistIvSetter is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        // OptionPricingLinearV2_1().updateIVSetter(
        //     ,
        // );
        OptionPricingLinearV2_1(address(0)).updateIVSetter(0x04A492F02Aa52cC0f1B1D3eD43bFeE17244eEd2a, true);

        // OptionPricingLinearV2_1().transferOwnership();
        // OptionPricingLinearV2_1().transferOwnership();

        vm.stopBroadcast();
    }
}
