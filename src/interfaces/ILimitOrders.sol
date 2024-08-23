// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IOptionMarket} from "./IOptionMarket.sol";
import {ISwapper} from "./ISwapper.sol";

interface ILimitOrders {
    function exerciseOption(
        Order memory _order,
        Signature calldata _signature,
        ExerciseOptionsSwapData calldata _swapData
    ) external returns (uint256 comission);

    struct BlockTradeOrder {
        uint256 payment;
        uint256 tokenId;
        IOptionMarket optionMarket;
        IERC20 token;
        address taker;
    }

    struct PurchaseOrder {
        uint256 maxCostAllowance;
        uint256 ttl;
        IOptionMarket optionMarket;
        uint256 liquidity;
        uint256 comission;
        uint256 ttlThreshold;
        int24 tickLower;
        int24 tickUpper;
        bool isCall;
    }

    struct Order {
        uint256 createdAt;
        uint256 deadline;
        address maker;
        address validator;
        uint32 flags;
        bytes data;
    }

    struct ExerciseOptionsSwapData {
        ISwapper[] swapper;
        bytes[] swapData;
    }

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }
}
