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

    uint32 constant SELL_OPTIONS_FLAG = 0x0000100;

    uint32 constant BUY_OPTIONS_FLAG = 0x00000200;

    function hasOtcFlag(ILimitOrders.Order memory order) internal view returns (bool) {
        return (order.flags & OTC_FLAG) != 0;
    }

    function hasMarketFillFlag(ILimitOrders.Order memory order) internal returns (bool) {
        return (order.flags & MARKET_FILL_FLAG) != 0;
    }

    function hasSellOptionsFlag(ILimitOrders.Order memory order) internal returns (bool) {
        return (order.flags & SELL_OPTIONS_FLAG) != 0;
    }

    function hasBuyOptionsFlag(ILimitOrders.Order memory order) internal returns (bool) {
        return (order.flags & BUY_OPTIONS_FLAG) != 0;
    }

    function hasSellOptionsWithMarketFillFlags(ILimitOrders.Order memory order) internal returns (bool) {
        return hasSellOptionsFlag(order) && hasMarketFillFlag(order);
    }

    function hasSellOptionsWithOtcAndMarketFillFlags(ILimitOrders.Order memory order) internal returns (bool) {
        return hasSellOptionsFlag(order) && hasOtcFlag(order) && hasMarketFillFlag(order);
    }

    function hasBuyOptionsWithMarketFillFlags(ILimitOrders.Order memory order) internal returns (bool) {
        return hasBuyOptionsFlag(order) && hasMarketFillFlag(order);
    }

    function hasBuyOptionsWithOtcAndMarketFillFlags(ILimitOrders.Order memory order) internal returns (bool) {
        return hasBuyOptionsFlag(order) && hasOtcFlag(order) && hasMarketFillFlag(order);
    }

    function hasSellOptionsWithOtcFlags(ILimitOrders.Order memory order) internal returns (bool) {
        return hasSellOptionsFlag(order) && hasOtcFlag(order);
    }

    function hasBuyOptionsWithOtcFlags(ILimitOrders.Order memory order) internal returns (bool) {
        return hasBuyOptionsFlag(order) && hasOtcFlag(order);
    }

    function isExpired(ILimitOrders.Order memory order) internal view returns (bool) {
        return order.deadline < block.timestamp;
    }
}
