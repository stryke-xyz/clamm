// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

interface IOptionMarket {
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

contract OpenSettlement is AccessControl, Multicall {
    using SafeERC20 for IERC20;

    uint256 public timeToSettle = 2 hours;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    error OpenSettlement__NotExpired();
    error OpenSettlement__TooSoonOpenSettle();

    function openSettle(
        IOptionMarket market,
        uint256 tokenId,
        IOptionMarket.SettleOptionParams calldata _params
    ) public {
        IOptionMarket.OptionData memory opData = market.opData(tokenId);

        if (opData.expiry >= block.timestamp)
            revert OpenSettlement__NotExpired();

        if (block.timestamp - opData.expiry <= timeToSettle)
            revert OpenSettlement__TooSoonOpenSettle();

        market.settleOption(_params);

        uint256 callAssetBalance = IERC20(market.callAsset()).balanceOf(
            address(this)
        );
        uint256 putAssetBalance = IERC20(market.putAsset()).balanceOf(
            address(this)
        );

        if (callAssetBalance > 0) {
            IERC20(market.callAsset()).safeTransfer(
                msg.sender,
                callAssetBalance
            );
        }

        if (putAssetBalance > 0) {
            IERC20(market.putAsset()).safeTransfer(msg.sender, putAssetBalance);
        }
    }

    function updateTimeToSettle(
        uint256 _newTime
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        timeToSettle = _newTime;
    }
}
