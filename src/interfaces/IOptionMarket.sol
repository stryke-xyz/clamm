// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "./ISwapper.sol";

interface IOptionMarket {
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

    function exerciseOption(ExerciseOptionParams calldata _params) external;

    function settleOption(SettleOptionParams calldata _params) external;

    function callAsset() external view returns (address);

    function putAsset() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);
}
