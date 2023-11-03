// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Interfaces
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IDopexV2ClammFeeStrategy} from "./IDopexV2ClammFeeStrategy.sol";

// Contracts
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IDopexV2OptionPools {
    function callAsset() external view returns (address);

    function putAsset() external view returns (address);
}

/// @title DopexV2ClammFeeStrategy
/// @author witherblock
/// @notice Computes the fee for an option purchase on Dopex V2 CLAMM
contract DopexV2ClammFeeStrategy is IDopexV2ClammFeeStrategy, Ownable {
    /// @dev Option Pool address => OptionPoolInfo Struct
    mapping(address => OptionPoolInfo) public optionPoolInfo;

    /// @dev Option Pool address => Fee Struct
    mapping(address => FeeStruct) public feeStructs;

    /// @dev The precision in which fee percent is set (fee percent should always be divided by 1e6 to get the correct vaue)
    uint256 public constant FEE_PERCENT_PRECISION = 1e4;

    struct OptionPoolInfo {
        /// @dev Decimals of the call asset ERC20 token
        uint256 callAssetDecimals;
        /// @dev Decimals of the put asset ERC20 token
        uint256 putAssetDecimals;
    }

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
        optionPoolInfo[_optionPool] = OptionPoolInfo({
            callAssetDecimals: IERC20Metadata(
                IDopexV2OptionPools(_optionPool).callAsset()
            ).decimals(),
            putAssetDecimals: IERC20Metadata(
                IDopexV2OptionPools(_optionPool).putAsset()
            ).decimals()
        });
        feeStructs[_optionPool] = _feeStruct;

        emit OptionPoolRegistered(
            _optionPool,
            _feeStruct,
            optionPoolInfo[_optionPool]
        );
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
        bool _isCall,
        uint256 _amount,
        uint256 _price,
        uint256 _premium
    ) external view returns (uint256 fee) {
        uint256 feePercentage = feeStructs[_optionPool].feePercentage;
        uint256 decimals = _isCall
            ? optionPoolInfo[_optionPool].callAssetDecimals
            : optionPoolInfo[_optionPool].callAssetDecimals;

        // If decimals is 0 it means that the option pool was not registered
        if (decimals == 0) {
            revert OptionPoolNotRegistered(_optionPool);
        }

        fee =
            (feePercentage * _amount * _price) /
            (10 ** (decimals) * FEE_PERCENT_PRECISION * 100);

        uint256 maxFee = (_premium *
            feeStructs[_optionPool].maxFeePercentageOnPremium) /
            (FEE_PERCENT_PRECISION * 100);

        if (fee > maxFee) fee = maxFee;
    }

    error OptionPoolNotRegistered(address optionPool);

    event OptionPoolRegistered(
        address optionPool,
        FeeStruct feeStruct,
        OptionPoolInfo optionPoolInfo
    );

    event FeeUpdate(address optionPool, FeeStruct feeStruct);
}
