// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Libraries
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {BlackScholes} from "./external/BlackScholes.sol";
import {ABDKMathQuad} from "./external/ABDKMathQuad.sol";

// Contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OptionPricing is Ownable {
    using SafeMath for uint256;

    // The max volatility possible
    uint256 public volatilityCap;

    // The % of the price of asset which is the minimum option price possible in 1e8 precision
    uint256 public minOptionPricePercentage;

    constructor(uint256 _volatilityCap, uint256 _minOptionPricePercentage) {
        volatilityCap = _volatilityCap;
        minOptionPricePercentage = _minOptionPricePercentage;
    }

    /*---- GOVERNANCE FUNCTIONS ----*/

    /// @notice updates volatility cap for an option pool
    /// @param _volatilityCap the new volatility cap
    /// @return whether volatility cap was updated
    function updateVolatilityCap(uint256 _volatilityCap) external onlyOwner returns (bool) {
        volatilityCap = _volatilityCap;

        return true;
    }

    /// @notice updates % of the price of asset which is the minimum option price possible
    /// @param _minOptionPricePercentage the new %
    /// @return whether % was updated
    function updateMinOptionPricePercentage(uint256 _minOptionPricePercentage) external onlyOwner returns (bool) {
        minOptionPricePercentage = _minOptionPricePercentage;

        return true;
    }

    /*---- VIEWS ----*/

    /**
     * @notice computes the option price (with liquidity multiplier)
     * @param isPut is put option
     * @param expiry expiry timestamp
     * @param strike strike price
     * @param lastPrice current price
     * @param volatility volatility
     */
    function getOptionPrice(bool isPut, uint256 expiry, uint256 strike, uint256 lastPrice, uint256 volatility)
        external
        view
        returns (uint256)
    {
        uint256 timeToExpiry = expiry.sub(block.timestamp).div(864);

        uint256 optionPrice = BlackScholes.calculate(isPut ? 1 : 0, lastPrice, strike, timeToExpiry, 0, volatility) // 0 - Put, 1 - Call
                // Number of days to expiry mul by 100
            .div(BlackScholes.DIVISOR);

        uint256 minOptionPrice = lastPrice.mul(minOptionPricePercentage).div(1e10);

        if (minOptionPrice > optionPrice) {
            return minOptionPrice;
        }

        return optionPrice;
    }
}
