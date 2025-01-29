// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "../interfaces/ISwapper.sol";
import {ISwapRouter} from "./v3-core/contracts/interfaces/ISwapRouter.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapRouterSwapper is ISwapper {
    using SafeERC20 for IERC20;

    ISwapRouter public immutable sr;

    constructor(address _sr) {
        sr = ISwapRouter(_sr);
    }

    function onSwapReceived(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        bytes memory _swapData
    ) external returns (uint256 amountOut) {
        (int24 tickSpacing, uint256 amountOutMinimum) = abi.decode(
            _swapData,
            (int24, uint256)
        );

        IERC20(_tokenIn).safeIncreaseAllowance(address(sr), _amountIn);

        amountOut = sr.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                tickSpacing: tickSpacing,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
