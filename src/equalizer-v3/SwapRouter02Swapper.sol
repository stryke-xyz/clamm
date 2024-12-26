// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISwapper} from "../interfaces/ISwapper.sol";
import {ISwapRouter02} from "./v3-periphery/interfaces/ISwapRouter02.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapRouter02Swapper is ISwapper {
    using SafeERC20 for IERC20;

    ISwapRouter02 public immutable sr;

    constructor(address _sr) {
        sr = ISwapRouter02(_sr);
    }

    function onSwapReceived(address _tokenIn, address _tokenOut, uint256 _amountIn, bytes memory _swapData)
        external
        returns (uint256 amountOut)
    {
        (int24 tickSpacing, uint256 amountOutMinimum) = abi.decode(_swapData, (int24, uint256));

        IERC20(_tokenIn).safeIncreaseAllowance(address(sr), _amountIn);

        amountOut = sr.exactInputSingle{value: 0}(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                tickSpacing: tickSpacing,
                recipient: msg.sender,
                amountIn: _amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
