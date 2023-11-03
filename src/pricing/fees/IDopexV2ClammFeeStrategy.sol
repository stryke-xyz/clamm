// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDopexV2ClammFeeStrategy {
    /// @notice Computes the fee for an option purchase on Dopex V2 CLAMM
    /// @param _optionPool Address of the option pool
    /// @param _isCall Call or Put Option
    /// @param _amount Notional Amount
    /// @param _price Current price of the underlying (call asset)
    /// @param _premium Total premium being charged for the option purchase
    /// @return fee the computed fee
    function onFeeReqReceive(
        address _optionPool,
        bool _isCall,
        uint256 _amount,
        uint256 _price,
        uint256 _premium
    ) external view returns (uint256 fee);
}
