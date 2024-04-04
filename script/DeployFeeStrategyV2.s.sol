// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {DopexV2ClammFeeStrategyV2} from "../src/pricing/fees/DopexV2ClammFeeStrategyV2.sol";

contract DeployFeeStrategy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        DopexV2ClammFeeStrategyV2 feeStrategy = new DopexV2ClammFeeStrategyV2();
        console.log(address(feeStrategy));

        feeStrategy.registerOptionMarket(0x501B03BdB431154b8Df17BF1c00756E3a8F21744, 340000);
        feeStrategy.registerOptionMarket(0x550e7E236912DaA302F7d5D0d6e5D7b6EF191f04, 340000);
        feeStrategy.registerOptionMarket(0x4eed3A2b797Bf5630517EcCe2e31C1438A76bb92, 340000);
        vm.stopBroadcast();
    }
}
