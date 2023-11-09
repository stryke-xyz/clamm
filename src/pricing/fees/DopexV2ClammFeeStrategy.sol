// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Interfaces
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IDopexV2ClammFeeStrategy} from "./IDopexV2ClammFeeStrategy.sol";

// Contracts
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title DopexV2ClammFeeStrategy
/// @author witherblock
/// @notice Computes the fee for an option purchase on Dopex V2 CLAMM
contract DopexV2ClammFeeStrategy is IDopexV2ClammFeeStrategy, Ownable {
    /// @dev Option Market address => bool (is registered or not)
    mapping(address => bool) public registeredOptionMarkets;

    /// @dev Option Market address => Fee Percentage (fee percentage on premium)
    mapping(address => uint256) public feePercentages;

    /// @dev The precision in which fee percent is set (fee percent should always be divided by 1e6 to get the correct vaue)
    uint256 public constant FEE_PERCENT_PRECISION = 1e4;

    /// @notice Registers an option market with the fee strategy
    /// @dev Can only be called by owner.
    /// @param _optionMarket Address of the option market
    /// @param _feePercentage Fee percentage
    function registerOptionMarket(
        address _optionMarket,
        uint256 _feePercentage
    ) external onlyOwner {
        registeredOptionMarkets[_optionMarket] = true;

        updateFees(_optionMarket, _feePercentage);

        emit OptionMarketRegistered(_optionMarket);
    }

    /// @notice Updates the fee struct of an option market
    /// @dev Can only be called by owner.
    /// @param _optionMarket Address of the option market
    /// @param _feePercentage Fee percentage
    function updateFees(
        address _optionMarket,
        uint256 _feePercentage
    ) public onlyOwner {
        require(
            _feePercentage < FEE_PERCENT_PRECISION * 100,
            "Fee percentage cannot be 100 or more"
        );

        feePercentages[_optionMarket] = _feePercentage;

        emit FeeUpdate(_optionMarket, _feePercentage);
    }

    /// @inheritdoc	IDopexV2ClammFeeStrategy
    function onFeeReqReceive(
        address _optionMarket,
        uint256,
        uint256,
        uint256 _premium
    ) external view returns (uint256 fee) {
        uint256 feePercentage = feePercentages[_optionMarket];

        // If decimals is 0 it means that the option market was not registered
        if (!registeredOptionMarkets[_optionMarket]) {
            revert OptionMarketNotRegistered(_optionMarket);
        }

        fee = (feePercentage * _premium) / (FEE_PERCENT_PRECISION * 100);
    }

    error OptionMarketNotRegistered(address optionMarket);

    event OptionMarketRegistered(address optionMarket);

    event FeeUpdate(address optionMarket, uint256 feePercentages);
}
