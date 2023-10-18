// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IDopexFee} from "../interfaces/IDopexFee.sol";

contract DopexFee is IDopexFee {
    function onFeeReqReceive() external view returns (uint256) {
        return 0;
    }
}
