// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {AutoExerciseTimeBased} from "../src/periphery/AutoExerciseTimeBased.sol";

contract DeployAutoExercise is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        AutoExerciseTimeBased aetb = new AutoExerciseTimeBased();

        aetb.updateFeeTo(address(0));
        aetb.grantRole(keccak256("EXECUTOR"), address(0));

        console.log(address(aetb));
        vm.stopBroadcast();
    }
}
