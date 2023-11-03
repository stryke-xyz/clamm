// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {UniswapV3SingleTickLiquidityHandler} from "../src/handlers/UniswapV3SingleTickLiquidityHandler.sol";

contract DeployPositionManager is Script {
    function run() public {
        address pm = 0x672436dB2468D9B736f4Ec8300CAc3532303f88b;
        address op = 0x58c4d160b33aC1fE89c136c598CEdc9C299D8a0f;
        address uniV3Handler = 0xfe30F2e6cDcEA6815EF396d81Db5bE2B5C43166c;
        vm.startBroadcast();

        DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(
            uniV3Handler,
            op,
            true
        );

        DopexV2PositionManager(pm).updateWhitelistHandler(uniV3Handler, true);

        UniswapV3SingleTickLiquidityHandler(uniV3Handler).updateWhitelistedApps(
            pm,
            true
        );

        vm.stopBroadcast();
    }
}
