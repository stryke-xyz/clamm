// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC6909} from "../interfaces/IERC6909.sol";

import {IOptionMarket} from "../interfaces/IOptionMarket.sol";
import {IHandler} from "../interfaces/IHandler.sol";
import {IDopexV2PositionManager} from "../interfaces/IDopexV2PositionManager.sol";

import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title ClammRouter
 * @author psytama
 * @dev Allow traders to buy CALL and PUT options using Dopex Option Market
 */
contract ClammRouter is Multicall, IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;

    address public dopexV2PositionManager;

    // events
    event LogMintOption(
        address user, address receiver, address optionMarket, uint256 tokenId, bytes32 frontendId, bytes32 referralId
    );

    event LogMintPosition(
        IHandler _handler,
        uint256 tokenId,
        address user,
        address receiver,
        uint256 sharesMinted,
        bytes32 frontendId,
        bytes32 referralId
    );

    // functions
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setPositionsManager(address _dopexV2PositionManager) external onlyOwner {
        dopexV2PositionManager = _dopexV2PositionManager;
    }

    function mintOption(
        IOptionMarket.OptionParams calldata _params,
        address optionMarket,
        address receiver,
        bytes32 frontendId,
        bytes32 referralId
    ) external {
        address token =
            _params.isCall ? IOptionMarket(optionMarket).callAsset() : IOptionMarket(optionMarket).putAsset();

        // transfer cost from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), _params.maxCostAllowance);

        // approve optionMarket to spend the cost
        IERC20(token).approve(optionMarket, _params.maxCostAllowance);

        // mint option
        IOptionMarket(optionMarket).mintOption(_params);

        // send the option to the receiver
        uint256 tokenId = IOptionMarket(optionMarket).optionIds();

        IERC721(optionMarket).safeTransferFrom(address(this), receiver, tokenId);

        // refund the remaining cost
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));

        // emit event
        emit LogMintOption(msg.sender, receiver, optionMarket, tokenId, frontendId, referralId);
    }

    function mintPosition(
        IHandler _handler,
        bytes calldata _mintPositionData,
        address receiver,
        bytes32 frontendId,
        bytes32 referralId
    ) external returns (uint256 sharesMinted) {
        // get token Id
        uint256 tokenId = _handler.getHandlerIdentifier(_mintPositionData);

        // get tokens and amounts
        (address[] memory tokens, uint256[] memory amounts) = _handler.tokensToPullForMint(_mintPositionData);

        // transfer amount from user to this contract
        uint256 amount;
        for (uint256 i; i < tokens.length; i++) {
            amount = amounts[i];
            if (amount != 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amount);
                IERC20(tokens[i]).safeIncreaseAllowance(address(dopexV2PositionManager), amount);
            }
        }

        // mint position
        sharesMinted = IDopexV2PositionManager(dopexV2PositionManager).mintPosition(_handler, _mintPositionData);

        // send the shares to the user
        IERC6909(address(_handler)).transfer(receiver, tokenId, sharesMinted);

        emit LogMintPosition(_handler, tokenId, msg.sender, receiver, sharesMinted, frontendId, referralId);
    }
}
