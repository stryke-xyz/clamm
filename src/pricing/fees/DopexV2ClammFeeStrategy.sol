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

    /// @dev Option Pool address => Fee Struct
    mapping(address => FeeStruct) public feeStructs;

    /// @dev The precision in which fee percent is set (fee percent should always be divided by 1e6 to get the correct vaue)
    uint256 public constant FEE_PERCENT_PRECISION = 1e4;

    struct FeeStruct {
        /// @dev Fee percentage on the notional value
        uint256 feePercentage;
        /// @dev Max fee percentage of the premium
        uint256 maxFeePercentageOnPremium;
    }

    /// @notice Registers an option pool with the fee strategy
    /// @dev Can only be called by owner.
    /// @param _optionPool Address of the option pool
    /// @param _feeStruct FeeStruct
    function registerOptionPool(
        address _optionPool,
        FeeStruct memory _feeStruct
    ) external onlyOwner {
        registeredOptionPools[_optionPool] = true;
        feeStructs[_optionPool] = _feeStruct;

        emit OptionPoolRegistered(_optionPool, _feeStruct);
    }

    /// @notice Updates the fee struct of an option pool
    /// @dev Can only be called by owner.
    /// @param _optionPool Address of the option pool
    /// @param _feeStruct FeeStruct
    function updateFees(
        address _optionPool,
        FeeStruct memory _feeStruct
    ) external onlyOwner {
        feeStructs[_optionPool] = _feeStruct;

        emit FeeUpdate(_optionPool, _feeStruct);
    }

    /// @inheritdoc	IDopexV2ClammFeeStrategy
    function onFeeReqReceive(
        address _optionPool,
        uint256 _amount,
        uint256 _premium
    ) external view returns (uint256 fee) {
        uint256 feePercentage = feeStructs[_optionPool].feePercentage;

        // If decimals is 0 it means that the option pool was not registered
        if (registeredOptionPools[_optionPool]) {
            revert OptionPoolNotRegistered(_optionPool);
        }

        fee = (feePercentage * _amount) / (FEE_PERCENT_PRECISION * 100);

        uint256 maxFee = (_premium *
            feeStructs[_optionPool].maxFeePercentageOnPremium) /
            (FEE_PERCENT_PRECISION * 100);

        if (fee > maxFee) fee = maxFee;
    }

    error OptionPoolNotRegistered(address optionPool);

    event OptionPoolRegistered(address optionPool, FeeStruct feeStruct);

    event FeeUpdate(address optionPool, FeeStruct feeStruct);
}
