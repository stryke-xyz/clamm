// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {UniswapV3SingleTickLiquidityHandler} from "../src/handlers/UniswapV3SingleTickLiquidityHandler.sol";

contract DeployPositionManager is Script {
    function run() public {
        address pm = 0x1e3d4725dB1062b88962bFAb8B2D31eAa8f63e45;
        address op = 0x7d6BA9528A1449Fa944D81Ea16089D0db01F2A20;
        address uniV3Handler = 0xBdAd87fFcB972E55A94C0aDca42E2c21441070A1;
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
