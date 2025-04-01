// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2PositionManagerV2} from "../src/DopexV2PositionManagerV2.sol";

contract DeployPositionManagerV2 is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        DopexV2PositionManagerV2 pm = new DopexV2PositionManagerV2();
        console.log(address(pm));
        vm.stopBroadcast();
    }
}
