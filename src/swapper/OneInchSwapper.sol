// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "../interfaces/ISwapper.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract OneInchSwapper is ISwapper {
    using SafeERC20 for IERC20;

    address public immutable oneInchRouter;

    constructor(address _oneInchRouter) {
        oneInchRouter = _oneInchRouter;
    }

    function onSwapReceived(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        bytes memory _swapData
    ) external returns (uint256 amountOut) {
        IERC20(_tokenIn).safeIncreaseAllowance(oneInchRouter, _amountIn);

        // inch should directly send to the option pool contract
        (bool success, ) = oneInchRouter.call(_swapData);
        require(success);
    }
}
