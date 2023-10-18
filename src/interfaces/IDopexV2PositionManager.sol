// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IHandler} from "./IHandler.sol";

interface IDopexV2PositionManager {
    function mintPosition(
        IHandler _handler,
        bytes calldata _mintPositionData
    ) external returns (uint256 sharesMinted);

    function burnPosition(
        IHandler _handler,
        bytes calldata _burnPositionData
    ) external returns (uint256 sharesBurned);

    function usePosition(
        IHandler _handler,
        bytes calldata _usePositionData
    )
        external
        returns (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 liquidityUsed
        );

    function unusePosition(
        IHandler _handler,
        bytes calldata _unusePositionData
    ) external returns (uint256[] memory amounts, uint256 liquidity);

    function donateToPosition(
        IHandler _handler,
        bytes calldata _donatePosition
    ) external returns (uint256[] memory amounts, uint256 liquidity);
}
