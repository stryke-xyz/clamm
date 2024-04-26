// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "./ISwapper.sol";
import {IHandler} from "./IHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

interface IOptionMarket {
    struct OptionTicks {
        IHandler _handler;
        IUniswapV3Pool pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidityToUse;
    }

    struct OptionParams {
        OptionTicks[] optionTicks;
        int24 tickLower;
        int24 tickUpper;
        uint256 ttl;
        bool isCall;
        uint256 maxCostAllowance;
    }

    struct SettleOptionParams {
        uint256 optionId;
        ISwapper[] swapper;
        bytes[] swapData;
        uint256[] liquidityToSettle;
    }

    struct ExerciseOptionParams {
        uint256 optionId;
        ISwapper[] swapper;
        bytes[] swapData;
        uint256[] liquidityToExercise;
    }

    struct OptionData {
        uint256 opTickArrayLen;
        int24 tickLower;
        int24 tickUpper;
        uint256 expiry;
        bool isCall;
    }

    function opData(uint256 tokenId) external view returns (OptionData memory);

    function mintOption(OptionParams calldata _params) external;

    function exerciseOption(ExerciseOptionParams calldata _params) external;

    function settleOption(SettleOptionParams calldata _params) external;

    function callAsset() external view returns (address);

    function putAsset() external view returns (address);

    function optionIds() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function balanceOf(address owner) external view returns (uint256);
}
