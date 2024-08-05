// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {ILimitOrders} from "../../interfaces/ILimitOrders.sol";

library OrderLib {
    /**
     * @notice Only allows the specified taker or maker to fullfill
     *         - Options and payments are exchanged between taker and m
     */
    uint32 constant OTC_FLAG = 0x00000001;
    /**
     * @notice Allows to be fullfilled by anyone
     *         Limit exercise orders:
     *          - exercise the option if min profit condition is satisfied
     *         OTC/Block trade orders:
     *          - Purchases option from option market
     */
    uint32 constant MARKET_FILL_FLAG = 0x0000010;

    uint32 constant PERMIT2_FLAG = 0x10000000;

    function hasOtcFlag(ILimitOrders.Order memory order) internal view returns (bool) {
        return (order.flags & OTC_FLAG) != 0;
    }

    function hasMarketFillFlag(ILimitOrders.Order memory order) internal returns (bool) {
        return (order.flags & MARKET_FILL_FLAG) != 0;
    }

    function hasPermit2Flag(ILimitOrders.Order memory order) internal returns (bool) {
        return (order.flags & PERMIT2_FLAG) != 0;
    }

    function isExpired(ILimitOrders.Order memory order) internal view returns (bool) {
        return order.deadline < block.timestamp;
    }
}
