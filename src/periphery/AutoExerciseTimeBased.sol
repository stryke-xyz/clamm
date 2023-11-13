// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IOptionMarket {
    struct ExerciseOptionParams {
        uint256 optionId;
        ISwapper swapper;
        bytes swapData;
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

    function callAsset() external view returns (address);

    function putAsset() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);
}

contract AutoExerciseTimeBased is AccessControl {
    using SafeERC20 for IERC20;

    address public feeTo;

    uint256 public constant MAX_EXECUTOR_FEE = 1e5;

    uint256 public constant EXECUTOR_FEE_PRECISION = 1e6;

    uint256 public timeToSettle = 5 minutes;

    bytes32 constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(EXECUTOR_ROLE, DEFAULT_ADMIN_ROLE);
    }

    // errors
    error AutoExerciseOneMin__AlreadyExpired();
    error AutoExerciseOneMin__TooSoon();
    error AutoExerciseOneMin__GreedyExecutor();

    function autoExercise(
        IOptionMarket market,
        uint256 tokenId,
        uint256 executorFee,
        IOptionMarket.ExerciseOptionParams calldata _params
    ) external onlyRole(EXECUTOR_ROLE) {
        IOptionMarket.OptionData memory opData = market.opData(tokenId);

        if (opData.expiry < block.timestamp)
            revert AutoExerciseOneMin__AlreadyExpired();

        if (opData.expiry - block.timestamp > timeToSettle)
            revert AutoExerciseOneMin__TooSoon();

        if (executorFee > MAX_EXECUTOR_FEE)
            revert AutoExerciseOneMin__GreedyExecutor();

        market.exerciseOption(_params);

        if (opData.isCall) {
            address putAsset = market.putAsset();
            uint256 amountAfterExercise = IERC20(putAsset).balanceOf(
                address(this)
            );
            uint256 fees;
            if (feeTo != address(0)) {
                fees =
                    (amountAfterExercise * executorFee) /
                    EXECUTOR_FEE_PRECISION;

                IERC20(putAsset).safeTransfer(feeTo, fees);
            }

            IERC20(putAsset).safeTransfer(
                market.ownerOf(tokenId),
                amountAfterExercise - fees
            );
        } else {
            address callAsset = market.callAsset();
            uint256 amountAfterExercise = IERC20(callAsset).balanceOf(
                address(this)
            );
            uint256 fees;
            if (feeTo != address(0)) {
                fees =
                    (amountAfterExercise * executorFee) /
                    EXECUTOR_FEE_PRECISION;

                IERC20(callAsset).safeTransfer(feeTo, fees);
            }

            IERC20(callAsset).safeTransfer(
                market.ownerOf(tokenId),
                amountAfterExercise - fees
            );
        }
    }

    function updateFeeTo(
        address _newFeeTo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeTo = _newFeeTo;
    }

    function updateTimeForSettle(
        uint256 _newTime
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        timeToSettle = _newTime;
    }
}
