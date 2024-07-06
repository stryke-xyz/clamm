// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {LimitExercise} from "../src/periphery/LimitExercise.sol";

// source .env
// forge script --chain arbitrum script/DeployLimitExercise.s.sol:DeployLimitExercise --rpc-url $ARBITRUM_RPC_URL --verify -vvvv --private-key $DEPLOYER_PRIVATE_KEY  --legacy --broadcast
contract DeployLimitExercise is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address keeper = address(0);

        require(keeper != address(0), "keeper address zero in deploy script");

        LimitExercise limitExercise = new LimitExercise();

        limitExercise.grantRole(limitExercise.KEEPER_ROLE(), keeper);

        console.log(address(limitExercise));

        vm.stopBroadcast();
    }
}
