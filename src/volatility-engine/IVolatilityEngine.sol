// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVolatilityEngine {
    function getVolatility(
        bytes32 _id,
        uint256 _expiry,
        uint256 _strike
    ) external view returns (uint256);
}
