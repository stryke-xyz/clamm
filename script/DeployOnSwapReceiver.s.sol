// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {OnSwapReceiver} from "../src/swapper/OnSwapReceiver.sol";

contract DeployOnSwapReceiver is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        OnSwapReceiver swapper = new OnSwapReceiver();

        console.log(address(swapper));

        vm.stopBroadcast();
    }
}
