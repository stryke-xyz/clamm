// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IOptionPools {
    struct SettleOptionParams {
        uint256 optionId;
        ISwapper swapper;
        bytes swapData;
        uint256[] liquidityToSettle;
    }

    struct OptionData {
        uint256 opTickArrayLen;
        int24 tickLower;
        int24 tickUpper;
        uint256 expiry;
        bool isCall;
    }

    function opData(uint256 tokenId) external view returns (OptionData memory);

    function settleOption(SettleOptionParams calldata _params) external;

    function callAsset() external view returns (address);

    function putAsset() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);
}

contract OpenSettlement is AccessControl {
    using SafeERC20 for IERC20;

    uint256 public timeToSettle = 2 hours;

    bytes32 constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(EXECUTOR_ROLE, DEFAULT_ADMIN_ROLE);
    }

    error OpenSettlement__NotExpired();
    error OpenSettlement__TooSoonOpenSettle();

    function openSettle(
        IOptionPools pool,
        uint256 tokenId,
        IOptionPools.SettleOptionParams calldata _params
    ) public {
        IOptionPools.OptionData memory opData = pool.opData(tokenId);

        if (opData.expiry >= block.timestamp)
            revert OpenSettlement__NotExpired();

        if (block.timestamp - opData.expiry <= timeToSettle)
            revert OpenSettlement__TooSoonOpenSettle();

        pool.settleOption(_params);

        uint256 callAssetBalance = IERC20(pool.callAsset()).balanceOf(
            address(this)
        );
        uint256 putAssetBalance = IERC20(pool.putAsset()).balanceOf(
            address(this)
        );

        if (callAssetBalance > 0) {
            IERC20(pool.callAsset()).safeTransfer(msg.sender, callAssetBalance);
        }

        if (putAssetBalance > 0) {
            IERC20(pool.putAsset()).safeTransfer(msg.sender, putAssetBalance);
        }
    }
}