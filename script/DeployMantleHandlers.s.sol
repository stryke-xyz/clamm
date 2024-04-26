// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import {AgniSingleTickLiquidityHandlerV2} from "../src/handlers/AgniSingleTickLiquidityHandlerV2.sol";
// import {FusionXV3SingleTickLiquidityHandlerV2} from "../src/handlers/FusionXV3SingleTickLiquidityHandlerV2.sol";
// import {ButterSingleTickLiquidityHandlerV2} from "../src/handlers/ButterSingleTickLiquidityHandlerV2.sol";
// import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";

// contract DeployMantleHandlers is Script {
//     function run() public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

//         vm.startBroadcast(deployerPrivateKey);

//         AgniSingleTickLiquidityHandlerV2 agniHandler = new AgniSingleTickLiquidityHandlerV2();

//         agniHandler.updateWhitelistedApps(0xE4bA6740aF4c666325D49B3112E4758371386aDc, true);

//         DopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc).updateWhitelistHandler(
//             address(agniHandler), true
//         );

//         FusionXV3SingleTickLiquidityHandlerV2 fusionHandler = new FusionXV3SingleTickLiquidityHandlerV2();

//         fusionHandler.updateWhitelistedApps(0xE4bA6740aF4c666325D49B3112E4758371386aDc, true);

//         DopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc).updateWhitelistHandler(
//             address(fusionHandler), true
//         );

//         ButterSingleTickLiquidityHandlerV2 butterHandler = new ButterSingleTickLiquidityHandlerV2();

//         butterHandler.updateWhitelistedApps(0xE4bA6740aF4c666325D49B3112E4758371386aDc, true);

//         DopexV2PositionManager(0xE4bA6740aF4c666325D49B3112E4758371386aDc).updateWhitelistHandler(
//             address(butterHandler), true
//         );

//         console.log(address(agniHandler));
//         console.log(address(fusionHandler));
//         console.log(address(butterHandler));
//         vm.stopBroadcast();
//     }
// }
