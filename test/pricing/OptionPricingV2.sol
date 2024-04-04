// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Libraries
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {BlackScholes} from "./BlackScholes.sol";

// Contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OptionPricingV2 is Ownable {
    using SafeMath for uint256;

    error NotIVSetter();

    // The max volatility possible
    uint256 public volatilityCap;

    // The % of the price of asset which is the minimum option price possible in 1e8 precision
    uint256 public minOptionPricePercentage;

    mapping(uint256 => uint256) public ttlToVol;
    mapping(address => bool) public ivSetter;

    constructor(uint256 _volatilityCap, uint256 _minOptionPricePercentage) {
        volatilityCap = _volatilityCap;
        minOptionPricePercentage = _minOptionPricePercentage;

        ivSetter[msg.sender] = true;
    }

    /*---- GOVERNANCE FUNCTIONS ----*/

    /// @notice updates volatility cap for an option pool
    /// @param _volatilityCap the new volatility cap
    /// @return whether volatility cap was updated
    function updateVolatilityCap(
        uint256 _volatilityCap
    ) external onlyOwner returns (bool) {
        volatilityCap = _volatilityCap;

        return true;
    }

    /// @notice updates % of the price of asset which is the minimum option price possible
    /// @param _minOptionPricePercentage the new %
    /// @return whether % was updated
    function updateMinOptionPricePercentage(
        uint256 _minOptionPricePercentage
    ) external onlyOwner returns (bool) {
        minOptionPricePercentage = _minOptionPricePercentage;

        return true;
    }

    /**
     * @notice Updates the IV setter
     * @param _setter Address of the setter
     * @param _status Status  to set
     * @dev Only the owner of the contract can call this function
     */
    function updateIVSetter(address _setter, bool _status) external onlyOwner {
        ivSetter[_setter] = _status;
    }

    /**
     * @notice Updates the implied volatility (IV) for the given time to expirations (TTLs).
     * @param _ttls The TTLs to update the IV for.
     * @param _ttlIV The new IVs for the given TTLs.
     * @dev Only the IV SETTER can call this function.
     */
    function updateIVs(
        uint256[] calldata _ttls,
        uint256[] calldata _ttlIV
    ) external {
        if (!ivSetter[msg.sender]) revert NotIVSetter();

        for (uint256 i; i < _ttls.length; i++) {
            ttlToVol[_ttls[i]] = _ttlIV[i];
        }
    }

    /*---- VIEWS ----*/

    /**
     * @notice computes the option price (with liquidity multiplier)
     * @param isPut is put option
     * @param expiry expiry timestamp
     * @param strike strike price
     * @param lastPrice current price
     */
    function getOptionPrice(
        bool isPut,
        uint256 expiry,
        uint256 strike,
        uint256 lastPrice
    ) external view returns (uint256 optionPrice) {
        uint256 timeToExpiry = expiry.sub(block.timestamp).div(864);

        if(ttlToVol[expiry - block.timestamp] == 0) revert();

        optionPrice = BlackScholes
            .calculate(
                isPut ? 1 : 0, // 0 - Put, 1 - Call
                lastPrice,
                strike,
                timeToExpiry, // Number of days to expiry mul by 100
                0,
                ttlToVol[expiry - block.timestamp]
            )
            .div(BlackScholes.DIVISOR);

        uint256 minOptionPrice = lastPrice.mul(minOptionPricePercentage).div(
            1e10
        );

        if (minOptionPrice > optionPrice) {
            return minOptionPrice;
        }
    }
}
