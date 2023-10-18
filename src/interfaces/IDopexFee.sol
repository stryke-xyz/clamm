// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDopexFee {
    function onFeeReqReceive() external view returns (uint256 amount);
}
