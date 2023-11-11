// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {UniswapV3SingleTickLiquidityHandler} from "../src/handlers/UniswapV3SingleTickLiquidityHandler.sol";

contract DeployPositionManager is Script {
    function run() public {
        address pm = 0xE4bA6740aF4c666325D49B3112E4758371386aDc;
        address op = 0xBb1cF6f913DE129900faefb7FBDa2e247A7f22aF;
        address uniV3Handler = 0x08dD79AEA6046B1E509fB84B57c3f9D024484D09;
        vm.startBroadcast();

        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(
            uniV3Handler,
            op,
            true
        );

        // DopexV2PositionManager(pm).updateWhitelistHandler(uniV3Handler, true);

        // UniswapV3SingleTickLiquidityHandler(uniV3Handler).updateWhitelistedApps(
        //     pm,
        //     true
        // );

        vm.stopBroadcast();
    }
}
