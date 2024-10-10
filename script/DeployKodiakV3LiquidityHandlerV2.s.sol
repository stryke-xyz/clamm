// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {KodiakV3SingleTickLiquidityHandlerV2} from "../src/handlers/KodiakV3SingleTickLiquidityHandlerV2.sol";

contract DeployKodiakV3LiquidityHandlerV2 is Script {
    function run() public {
        address factory = 0x217Cd80795EfCa5025d47023da5c03a24fA95356;
        address swapRouter = 0x66E8F0Cf851cE9be42a2f133a8851Bc6b70B9EBd;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        KodiakV3SingleTickLiquidityHandlerV2 kodiakV3Handler = new KodiakV3SingleTickLiquidityHandlerV2(
            factory, 0x945f1441b8ff07828f05880b3d67ebdd0962e5fb81cb8d7c32e9610e866ff219, swapRouter
        );

        console.log(address(kodiakV3Handler));

        vm.stopBroadcast();
    }
}
