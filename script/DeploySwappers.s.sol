// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {SwapRouterSwapper} from "../src/swapper/SwapRouterSwapper.sol";
import {OneInchSwapper} from "../src/swapper/OneInchSwapper.sol";

contract DeploySwappers is Script {
    function run() public {
        address sr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        address oneInchRouter = 0x1111111254EEB25477B68fb85Ed929f73A960582;

        vm.startBroadcast();
        SwapRouterSwapper srs = new SwapRouterSwapper(sr);
        OneInchSwapper ois = new OneInchSwapper(oneInchRouter);
        console.log(address(srs));
        console.log(address(ois));
        vm.stopBroadcast();
    }
}
