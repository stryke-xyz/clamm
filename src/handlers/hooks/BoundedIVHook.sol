// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IHook} from "../../interfaces/IHook.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IOptionMarketV2 {
    function optionPricing() external view returns (address);
}

interface IOptionPricingLinearV2 {
    function ttlToVol(uint256 ttl) external view returns (uint256);
}

contract BoundedIVHook is IHook, Ownable {
    mapping (address=>bool) whitelistedApps;
    mapping (address=>uint256) minPrice;

    function onPositionUse(bytes calldata _data) external {
        (address app, uint256 ttl) = abi.decode(_data, (address, uint256));
        if (!whitelistedApps[app]) revert();
        address optionPricing = IOptionMarketV2(app).optionPricing();
        if (IOptionPricingLinearV2(optionPricing).ttlToVol(ttl) < 40) revert();
    }

    function onPositionUnUse(bytes calldata _data) external {}

    function updateWhitelistedAppsStatus(address app, bool status) external onlyOwner {
        whitelistedApps[app] = status;
    }

    function setMinPrice(uint256 price) external {
        minPrice[msg.sender] = price;
    }
}
