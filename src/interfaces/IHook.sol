// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHook {
    function onPositionUse(bytes calldata _data) external;

    function onPositionUnUse(bytes calldata _data) external;
}
