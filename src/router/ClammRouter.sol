// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IOptionMarket} from "../interfaces/IOptionMarket.sol";

import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ClammRouter
 * @author psytama
 * @dev Allow traders to buy CALL and PUT options using Dopex Option Market
 */
contract ClammRouter is Multicall, IERC721Receiver {
    using SafeERC20 for IERC20;

    // events
    event LogMintOption(
        address user, address receiver, address optionMarket, uint256 tokenId, bytes32 frontendId, bytes32 referalId
    );

    // functions
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function mintOption(
        IOptionMarket.OptionParams calldata _params,
        address optionMarket,
        address receiver,
        bytes32 frontendId,
        bytes32 referalId
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
        emit LogMintOption(msg.sender, receiver, optionMarket, tokenId, frontendId, referalId);
    }
}
