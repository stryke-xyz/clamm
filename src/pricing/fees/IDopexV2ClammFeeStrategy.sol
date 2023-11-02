// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDopexV2ClammFeeStrategy {
    function onFeeReqReceive(
        address optionPool,
        bool isCall,
        uint256 amount,
        uint256 price,
        uint256 premium
    ) external view returns (uint256 fee);
}
