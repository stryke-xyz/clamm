// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {OptionPricingLinear} from "../src/pricing/OptionPricingLinear.sol";

contract DeployOptionPricingLinear is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        OptionPricingLinear opl = new OptionPricingLinear(1e4, 1e3, 1e7);
        console.log(address(opl));
        vm.stopBroadcast();
    }
}
