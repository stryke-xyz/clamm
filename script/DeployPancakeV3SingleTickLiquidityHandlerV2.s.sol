// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {PancakeV3SingleTickLiquidityHandlerV2} from "../src/handlers/PancakeV3SingleTickLiquidityHandlerV2.sol";

contract DeployPancakeV3SingleTickLiquidityHandlerV2 is Script {
    function run() public {
        address factory = 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9;
        address sr = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        PancakeV3SingleTickLiquidityHandlerV2 pcsHandler = new PancakeV3SingleTickLiquidityHandlerV2(
            factory, 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2, sr
        );
        console.log(address(pcsHandler));
        vm.stopBroadcast();
    }
}
