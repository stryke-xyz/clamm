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

contract DopexV2ClammFeeStrategy is IDopexV2ClammFeeStrategy, Ownable {
    mapping(address => OptionPoolInfo) public optionPoolInfo;

    mapping(address => FeeStruct) public feeStructs;

    uint256 public constant FEE_PERCENT_PRECISION = 1e4;

    struct OptionPoolInfo {
        uint256 callAssetDecimals;
        uint256 putAssetDecimals;
    }

    struct FeeStruct {
        uint256 feePercentage;
        uint256 maxFeePercentageOnPremium;
    }

    function registerOptionPool(address _optionPool) external onlyOwner {
        optionPoolInfo[_optionPool] = OptionPoolInfo({
            callAssetDecimals: IERC20Metadata(
                IDopexV2OptionPools(_optionPool).callAsset()
            ).decimals(),
            putAssetDecimals: IERC20Metadata(
                IDopexV2OptionPools(_optionPool).putAsset()
            ).decimals()
        });
    }

    function updateFees(
        address _optionPool,
        FeeStruct memory _feeStruct
    ) external onlyOwner {
        feeStructs[_optionPool] = _feeStruct;
    }

    function onFeeReqReceive(
        address optionPool,
        bool isCall,
        uint256 amount,
        uint256 price,
        uint256 premium
    ) external view returns (uint256 fee) {
        uint256 feePercentage = feeStructs[optionPool].feePercentage;
        uint256 decimals = isCall
            ? optionPoolInfo[optionPool].callAssetDecimals
            : optionPoolInfo[optionPool].callAssetDecimals;

        fee =
            (feePercentage * amount * price) /
            (10 ** (decimals) * FEE_PERCENT_PRECISION * 100);

        uint256 maxFee = (premium *
            feeStructs[optionPool].maxFeePercentageOnPremium) /
            (FEE_PERCENT_PRECISION * 100);

        if (fee > maxFee) fee = maxFee;
    }
}
