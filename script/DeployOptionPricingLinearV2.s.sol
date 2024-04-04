// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {OptionPricingLinearV2} from "../src/pricing/OptionPricingLinearV2.sol";

contract DeployOptionPricingLinearV2 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        OptionPricingLinearV2 opl = new OptionPricingLinearV2(1e4, 1e3, 1e7);
        console.log(address(opl));
        vm.stopBroadcast();
    }
}
