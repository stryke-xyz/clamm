// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "./ISwapper.sol";
import {IHandler} from "./IHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

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

    struct PositionSplitterParams {
        uint256 optionId;
        address to;
        uint256[] liquidityToSplit;
    }

    struct AssetsCache {
        ERC20 assetToUse;
        ERC20 assetToGet;
        uint256 totalProfit;
        uint256 totalAssetRelocked;
    }

    function opData(uint256 tokenId) external view returns (OptionData memory);

    function opTickMap(uint256 tokenId, uint256 index) external view returns (OptionTicks memory);

    function mintOption(OptionParams calldata _params) external;

    function exerciseOption(ExerciseOptionParams calldata _params) external returns (AssetsCache memory);

    function settleOption(SettleOptionParams calldata _params) external;

    function callAsset() external view returns (address);

    function putAsset() external view returns (address);

    function optionIds() external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function positionSplitter(PositionSplitterParams calldata _params) external;

    function getApproved(uint256 id) external view returns (address result);

    function isApprovedForAll(address owner, address operator) external view returns (bool result);
}
