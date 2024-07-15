// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "../interfaces/ISwapper.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract OnSwapReceiver is ISwapper, Ownable {
    using SafeERC20 for IERC20;

    struct SwapData {
        uint256 minAmountOut;
        address to;
        bytes swapData;
    }

    error OnSwapReceiver__onSwapReceivedFail(bytes data);
    error OnSwapReceiver__InsufficientAmountOut();
    error OnSwapReceiver__AmountInNotReceived();
    error OnSwapReceiver__ZeroAddress();

    event OnSwapReceived(uint256 _amountIn, uint256 _amountOut, address _tokenIn, address _tokenOut, address _swapper);
    event SwapperWhitelisted(address _address, bool _isWhitelisted);

    mapping(address => bool) public whitelisted;

    function setWhitelisted(address _address, bool _isWhitelisted) public onlyOwner {
        whitelisted[_address] = _isWhitelisted;
        emit SwapperWhitelisted(_address, _isWhitelisted);
    }

    function onSwapReceived(address _tokenIn, address _tokenOut, uint256 _amountIn, bytes memory _swapData)
        external
        returns (uint256 amountOut)
    {
        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = IERC20(_tokenOut);

        bytes memory swapData;
        address to;
        uint256 minAmountout;

        (minAmountout, to, swapData) = abi.decode(_swapData, (uint256, address, bytes));

        if (_tokenIn == address(0) || _tokenOut == address(0) || to == address(0)) {
            revert OnSwapReceiver__ZeroAddress();
        }

        if (_amountIn > tokenIn.balanceOf((address(this)))) {
            revert OnSwapReceiver__AmountInNotReceived();
        }

        tokenIn.safeIncreaseAllowance(to, _amountIn);

        /**
         * @dev
         * receiver: address(this)
         * sender: address(this)
         */
        (bool success, bytes memory data) = to.call(swapData);

        if (!success) {
            revert OnSwapReceiver__onSwapReceivedFail(data);
        }

        amountOut = tokenOut.balanceOf(address(this));

        if (amountOut < minAmountout) {
            revert OnSwapReceiver__InsufficientAmountOut();
        }

        tokenOut.transfer(msg.sender, amountOut);

        emit OnSwapReceived(_amountIn, amountOut, _tokenIn, _tokenOut, to);
    }
}
