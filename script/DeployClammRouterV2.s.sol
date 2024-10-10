// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {ClammRouterV2} from "../src/router/ClammRouterV2.sol";

contract DeployClammRouterV2 is Script {
    function run() public {
        // NOTE: Change below before running this script
        address dopexV2PositionManager = address(0);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        ClammRouterV2 router = new ClammRouterV2();

        router.setDopexV2PositionManager(dopexV2PositionManager);

        console.log(address(router));

        vm.stopBroadcast();
    }
}
