// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// Contracts
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

// Interfaces
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISwapper} from "../interfaces/ISwapper.sol";
import {IOptionMarket} from "../interfaces/IOptionMarket.sol";

// Libraries
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract OpenSettlementV2 is AccessControl, Multicall {
    using SafeERC20 for IERC20;

    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");

    uint256 public commissionPercentage = 1e4;
    uint256 public constant COMISSION_PRECISION = 1e6;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function openSettle(
        IOptionMarket market,
        uint256 tokenId,
        IOptionMarket.SettleOptionParams calldata _params,
        address receiver
    ) external onlyRole(SETTLER_ROLE) {
        IOptionMarket.OptionData memory opData = market.opData(tokenId);

        address optionOwner = market.ownerOf(tokenId);

        market.settleOption(_params);

        uint256 callAssetBalance = IERC20(market.callAsset()).balanceOf(address(this));
        uint256 putAssetBalance = IERC20(market.putAsset()).balanceOf(address(this));
        uint256 comission = 0;

        if (callAssetBalance > 0) {
            comission = callAssetBalance * commissionPercentage / COMISSION_PRECISION;
            IERC20(market.callAsset()).safeTransfer(optionOwner, callAssetBalance - comission);
            IERC20(market.callAsset()).safeTransfer(receiver, comission);
        }

        if (putAssetBalance > 0) {
            comission = putAssetBalance * commissionPercentage / COMISSION_PRECISION;
            IERC20(market.putAsset()).safeTransfer(optionOwner, putAssetBalance - comission);
            IERC20(market.putAsset()).safeTransfer(receiver, comission);
        }
    }

    function sweep(IERC20 token, address receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token.transfer(receiver, token.balanceOf(address(this)));
    }

    function updateComission(uint256 newComission) external onlyRole(DEFAULT_ADMIN_ROLE) {
        commissionPercentage = newComission;
    }
}
