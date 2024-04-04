// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IOptionPricingV2 {
    function getOptionPrice(
        bool isPut,
        uint256 expiry,
        uint256 strike,
        uint256 lastPrice
    ) external view returns (uint256);
}
