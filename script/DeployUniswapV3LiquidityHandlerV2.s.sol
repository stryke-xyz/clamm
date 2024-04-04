// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {UniswapV3SingleTickLiquidityHandlerV2} from "../src/handlers/UniswapV3SingleTickLiquidityHandlerV2.sol";

contract DeployUniswapV3LiquidityHandlerV2 is Script {
    function run() public {
        address factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        address sr = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        UniswapV3SingleTickLiquidityHandlerV2 uniV3Handler = new UniswapV3SingleTickLiquidityHandlerV2(
            factory, 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, sr
        );
        console.log(address(uniV3Handler));
        vm.stopBroadcast();
    }
}
