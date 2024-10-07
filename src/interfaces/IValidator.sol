// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {ILimitOrders} from "./ILimitOrders.sol";

interface IValidator {
    function beforeFullfillment(ILimitOrders.Order calldata _order) external;
    function afterFullfillment(ILimitOrders.Order calldata _order) external;
}
