// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import {DopexV2OptionMarketV2} from "../src/DopexV2OptionMarketV2.sol";
// import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";

// contract DeployOptionMarketV2 is Script {
//     function run() public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

//         address optionPricing = 0x764fA09d0B3de61EeD242099BD9352C1C61D3d27;

//         address pm = 0xE4bA6740aF4c666325D49B3112E4758371386aDc;

//         address dpFee = 0xBb1cF6f913DE129900faefb7FBDa2e247A7f22aF;

//         address feeTo = 0x5674Ce0Dbb2B5973aB768fB40938524da927A459;

//         address callAsset = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;

//         address putAsset = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;

//         address primePool = 0x628f7131CF43e88EBe3921Ae78C4bA0C31872bd4;

//         vm.startBroadcast(deployerPrivateKey);
//         DopexV2OptionMarketV2 om = DopexV2OptionMarketV2(0xcDA890C42365dCb1A8a1079F2f47379Ad620bC99);
//         console.log(address(om));

//         // Whitelist all handlers
//         address agniHandler = 0x5DdA827f304Aeb693573720B344eD160e7D4703C;
//         address fusionHandler = 0x210D2963b555Ce5AC7e3d9b0e2F38d7AEBd4B43F;
//         address butterHandler = 0xD648267FC75e144f28436E7b54030C7466031b05;
//         DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(agniHandler, address(om), true);
//         DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(fusionHandler, address(om), true);
//         DopexV2PositionManager(pm).updateWhitelistHandlerWithApp(butterHandler, address(om), true);

//         // Add agni, fusion and butter pools
//         om.updateAddress(
//             feeTo, address(0), dpFee, optionPricing, 0x1041fB8Ab01D6E979601d5eC753E8A717B3d459d, true, primePool, true
//         );
//         om.updateAddress(
//             feeTo, address(0), dpFee, optionPricing, 0x3f4BC1FFADb1435F19909D31588F4ce12bC0e452, true, primePool, true
//         );
//         address butterPool = 0xD801D457D9cC70f6018a62885F03BB70706F59Cc;
//         om.updateAddress(
//             feeTo, address(0), dpFee, optionPricing, 0x7328908702DD919bC597a5291B4714b689d06b7A, true, butterPool, true
//         );
//         vm.stopBroadcast();
//     }
// }
