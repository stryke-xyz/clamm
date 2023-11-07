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
    /// @dev Option Pool address => bool (is registered or not)
    mapping(address => bool) public registeredOptionPools;

    /// @dev Option Pool address => Fee Percentage
    mapping(address => uint256) public feePercentages;

    /// @dev The precision in which fee percent is set (fee percent should always be divided by 1e6 to get the correct vaue)
    uint256 public constant FEE_PERCENT_PRECISION = 1e4;

    /// @notice Registers an option pool with the fee strategy
    /// @dev Can only be called by owner.
    /// @param _optionPool Address of the option pool
    /// @param _feePercentage Fee percentage
    function registerOptionPool(
        address _optionPool,
        uint256 _feePercentage
    ) external onlyOwner {
        registeredOptionPools[_optionPool] = true;

        updateFees(_optionPool, _feePercentage);

        emit OptionPoolRegistered(_optionPool);
    }

    /// @notice Updates the fee struct of an option pool
    /// @dev Can only be called by owner.
    /// @param _optionPool Address of the option pool
    /// @param _feePercentage Fee percentage
    function updateFees(
        address _optionPool,
        uint256 _feePercentage
    ) public onlyOwner {
        require(
            _feePercentage < FEE_PERCENT_PRECISION,
            "Fee percentage cannot be 100 or more"
        );

        feePercentages[_optionPool] = _feePercentage;

        emit FeeUpdate(_optionPool, _feePercentage);
    }

    /// @inheritdoc	IDopexV2ClammFeeStrategy
    function onFeeReqReceive(
        address _optionPool,
        uint256 _amount,
        uint256
    ) external view returns (uint256 fee) {
        uint256 feePercentage = feePercentages[_optionPool];

        // If decimals is 0 it means that the option pool was not registered
        if (registeredOptionPools[_optionPool]) {
            revert OptionPoolNotRegistered(_optionPool);
        }

        fee = (feePercentage * _amount) / (FEE_PERCENT_PRECISION * 100);
    }

    error OptionPoolNotRegistered(address optionPool);

    event OptionPoolRegistered(address optionPool);

    event FeeUpdate(address optionPool, uint256 feePercentages);
}
