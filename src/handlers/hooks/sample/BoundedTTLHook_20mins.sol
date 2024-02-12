// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IHook} from "../../../interfaces/IHook.sol";

contract BoundedTTLHook_20mins is IHook {
    function onPositionUse(bytes calldata _data) external {
        (, uint256 ttl) = abi.decode(_data, (address, uint256));
        if (ttl > 20 minutes) revert();
    }

    function onPositionUnUse(bytes calldata _data) external {}
}
