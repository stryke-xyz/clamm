// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/pricing/OptionPricingLinearV2.sol";

contract UpdateIV is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint256[] memory ttls = new uint256[](6);
        ttls[1] = 1 hours;
        ttls[2] = 2 hours;
        ttls[3] = 6 hours;
        ttls[4] = 12 hours;
        ttls[5] = 24 hours;

        uint256[] memory wethIvArray = new uint256[](6);
        wethIvArray[1] = 58;
        wethIvArray[2] = 54;
        wethIvArray[3] = 48;
        wethIvArray[4] = 44;
        wethIvArray[5] = 40;

        uint256[] memory wbtcIvArray = new uint256[](6);
        wbtcIvArray[1] = 58;
        wbtcIvArray[2] = 54;
        wbtcIvArray[3] = 48;
        wbtcIvArray[4] = 4;
        wbtcIvArray[5] = 40;

        uint256[] memory arbIvArray = new uint256[](6);
        arbIvArray[1] = 68;
        arbIvArray[2] = 62;
        arbIvArray[3] = 56;
        arbIvArray[4] = 50;
        arbIvArray[5] = 44;

        OptionPricingLinearV2 wethOp = OptionPricingLinearV2(0x60E86Cae8AdBd8157b2135689f67b957371E7513);
        OptionPricingLinearV2 wbtcOp = OptionPricingLinearV2(0x8B55C45EC7e6b1AFCDBf909FEe0A6Da12CFae70c);
        OptionPricingLinearV2 arbOp = OptionPricingLinearV2(0xfCf7514B9ba64567623eA219b7c099Bee95B8b04);

        wethOp.updateIVs(ttls, wethIvArray);
        wbtcOp.updateIVs(ttls, wbtcIvArray);
        arbOp.updateIVs(ttls, arbIvArray);

        vm.stopBroadcast();
    }
}
