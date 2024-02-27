// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IHook} from "../../interfaces/IHook.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {BokkyPooBahsDateTimeLibrary} from "../../../lib/BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract WeekendHook is IHook, Ownable {
    mapping (address=>bool) whitelistedApps;

    function onPositionUse(bytes calldata _data) external {
        (address app) = abi.decode(_data, (address));
        if (!whitelistedApps[app]) revert();
        if(BokkyPooBahsDateTimeLibrary.isWeekEnd(block.timestamp)) revert();
    }

    function onPositionUnUse(bytes calldata _data) external {}

    function updateWhitelistedAppsStatus(address app, bool status) external onlyOwner {
        whitelistedApps[app] = status;
    }
}
