// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IHandlerV3 {
    function getHandlerIdentifier(bytes calldata _data) external view returns (uint256 handlerIdentifierId);

    function tokensToPullForMint(bytes calldata _mintPositionData)
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);

    function mintPositionHandler(address context, bytes calldata _mintPositionData)
        external
        returns (uint256 sharesMinted);

    function burnPositionHandler(address context, bytes calldata _burnPositionData)
        external
        returns (uint256 sharesBurned);

    function usePositionHandler(bytes calldata _usePositionData)
        external
        returns (address[] memory tokens, uint256[] memory amounts, uint256 liquidityUsed);

    function tokensToPullForUnUse(bytes calldata _unusePositionData)
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);

    function unusePositionHandler(bytes calldata _unusePositionData)
        external
        returns (uint256[] memory amounts, uint256 liquidity);

    function donateToPosition(bytes calldata _donatePosition)
        external
        returns (uint256[] memory amounts, uint256 liquidity);

    function tokensToPullForDonate(bytes calldata _donatePosition)
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);

    function reserveLiquidity(address context, bytes calldata _reserveLiquidityParam) external returns (uint256);

    function withdrawReserveLiquidity(address context, bytes calldata _reserveLiquidityParam) external;
}
