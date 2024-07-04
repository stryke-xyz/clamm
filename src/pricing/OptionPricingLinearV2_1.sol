// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Libraries
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {BlackScholes} from "../../test/pricing/BlackScholes.sol";
import {ABDKMathQuad} from "../../test/pricing/ABDKMathQuad.sol";

// Contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OptionPricingLinearV2_1 is Ownable {
    using SafeMath for uint256;

    // The % of the price of asset which is the minimum option price possible in 1e8 precision
    uint256 public minOptionPricePercentage;

    // The decimal precision for volatility calculation
    uint256 public constant VOLATILITY_PRECISION = 1e4;

    // xSYK token address
    address public xSyk;

    // Time to expiry => volatility
    mapping(uint256 => uint256) public ttlToVol;

    // TTL => The offset for volatility calculation in 1e4 precision
    mapping(uint256 => uint256) public volatilityOffsets;

    // TTL => The multiplier for volatility calculation in 1e4 precision
    mapping(uint256 => uint256) public volatilityMultipliers;

    // IV Setter addresses
    mapping(address => bool) public ivSetter;

    // xSYK Balances for each tier
    uint256[] public xSykBalances;

    // Discount for each tier
    uint256[] public discounts;

    error NotIVSetter();

    event UpdatedIVs(address sender, uint256[] ttls, uint256[] ttlIVs);

    constructor(uint256 _minOptionPricePercentage, address _xSyk) {
        minOptionPricePercentage = _minOptionPricePercentage;
        xSyk = _xSyk;

        ivSetter[msg.sender] = true;
    }

    /*---- GOVERNANCE FUNCTIONS ----*/

    /// @notice Updates the IV setter
    /// @param _setter Address of the setter
    /// @param _status Status  to set
    /// @dev Only the owner of the contract can call this function
    function updateIVSetter(address _setter, bool _status) external onlyOwner {
        ivSetter[_setter] = _status;
    }

    /// @notice Updates the implied volatility (IV) for the given time to expirations (TTLs).
    /// @param _ttls The TTLs to update the IV for.
    /// @param _ttlIVs The new IVs for the given TTLs.
    /// @dev Only the IV SETTER can call this function.
    function updateIVs(uint256[] calldata _ttls, uint256[] calldata _ttlIVs) external {
        if (!ivSetter[msg.sender]) revert NotIVSetter();

        for (uint256 i; i < _ttls.length; i++) {
            ttlToVol[_ttls[i]] = _ttlIVs[i];
        }

        emit UpdatedIVs(msg.sender, _ttls, _ttlIVs);
    }

    /// @notice updates the offset for volatility calculation
    /// @param _volatilityOffsets the new offset
    /// @param _ttls The TTLs to update the volatility offset for.
    /// @return whether offset was updated
    function updateVolatilityOffset(uint256[] calldata _volatilityOffsets, uint256[] calldata _ttls)
        external
        onlyOwner
        returns (bool)
    {
        uint256 volatilityOffsetsLength = _volatilityOffsets.length;

        for (uint256 i; i < volatilityOffsetsLength;) {
            volatilityOffsets[_ttls[i]] = _volatilityOffsets[i];

            unchecked {
                ++i;
            }
        }

        return true;
    }

    /// @notice updates the multiplier for volatility calculation
    /// @param _volatilityMultipliers the new multiplier
    /// @param _ttls The TTLs to update the volatility multiplier for.
    /// @return whether multiplier was updated
    function updateVolatilityMultiplier(uint256[] calldata _volatilityMultipliers, uint256[] calldata _ttls)
        external
        onlyOwner
        returns (bool)
    {
        for (uint256 i = 0; i < _volatilityMultipliers.length; i++) {
            volatilityMultipliers[_ttls[i]] = _volatilityMultipliers[i];
        }

        return true;
    }

    /// @notice updates % of the price of asset which is  the minimum option price possible
    /// @param _minOptionPricePercentage the new %
    /// @return whether % was updated
    function updateMinOptionPricePercentage(uint256 _minOptionPricePercentage) external onlyOwner returns (bool) {
        minOptionPricePercentage = _minOptionPricePercentage;

        return true;
    }

    /// @notice sets the xSYK balances and discounts for each tier
    /// @param _xSykBalances the xSYK balances
    /// @param _discounts the discounts
    /// @return whether the balances and discounts were set
    function setXSykBalancesAndDiscounts(uint256[] calldata _xSykBalances, uint256[] calldata _discounts)
        external
        onlyOwner
        returns (bool)
    {
        xSykBalances = _xSykBalances;
        discounts = _discounts;

        return true;
    }

    /*---- VIEWS ----*/

    /// @notice computes the option price (with liquidity multiplier)
    /// @param isPut is put option
    /// @param expiry expiry timestamp
    /// @param strike strike price
    /// @param lastPrice current price
    function getOptionPrice(bool isPut, uint256 expiry, uint256 strike, uint256 lastPrice)
        external
        view
        returns (uint256)
    {
        uint256 timeToExpiry = expiry.sub(block.timestamp).div(864);

        uint256 volatility = ttlToVol[expiry - block.timestamp];

        if (volatility == 0) revert();

        volatility = getVolatility(strike, lastPrice, volatility, expiry - block.timestamp);

        uint256 optionPrice = BlackScholes.calculate(isPut ? 1 : 0, lastPrice, strike, timeToExpiry, 0, volatility) // 0 - Put, 1 - Call
                // Number of days to expiry mul by 100
            .div(BlackScholes.DIVISOR);

        uint256 minOptionPrice = lastPrice.mul(minOptionPricePercentage).div(1e10);

        if (minOptionPrice > optionPrice) {
            return minOptionPrice;
        }

        return optionPrice;
    }

    /// @notice computes the option price (with liquidity multiplier)
    /// @param isPut is put option
    /// @param ttl time to live for the option
    /// @param strike strike price
    /// @param lastPrice current price
    function getOptionPriceViaTTL(bool isPut, uint256 ttl, uint256 strike, uint256 lastPrice)
        external
        view
        returns (uint256)
    {
        uint256 timeToExpiry = ttl.div(864);

        uint256 volatility = ttlToVol[ttl];

        if (volatility == 0) revert();

        volatility = getVolatility(strike, lastPrice, volatility, ttl);

        uint256 optionPrice = BlackScholes.calculate(isPut ? 1 : 0, lastPrice, strike, timeToExpiry, 0, volatility) // 0 - Put, 1 - Call
                // Number of days to expiry mul by 100
            .div(BlackScholes.DIVISOR);

        uint256 minOptionPrice = lastPrice.mul(minOptionPricePercentage).div(1e10);

        if (minOptionPrice > optionPrice) {
            return minOptionPrice;
        }

        return optionPrice;
    }

    /// @notice computes the volatility for a strike
    /// @param strike strike price
    /// @param lastPrice current price
    /// @param volatility volatility
    function getVolatility(uint256 strike, uint256 lastPrice, uint256 volatility, uint256 ttl)
        public
        view
        returns (uint256)
    {
        uint256 percentageDifference = strike.mul(1e2).mul(VOLATILITY_PRECISION).div(lastPrice); // 1e4 in percentage precision (1e6 is 100%)

        if (strike > lastPrice) {
            percentageDifference = percentageDifference.sub(1e6);
        } else {
            percentageDifference = uint256(1e6).sub(percentageDifference);
        }

        uint256 scaleFactor =
            volatilityOffsets[ttl] + (percentageDifference.mul(volatilityMultipliers[ttl]).div(VOLATILITY_PRECISION));

        volatility = volatility.mul(scaleFactor).div(VOLATILITY_PRECISION);

        address userAddress = tx.origin;
        uint256 tiers = xSykBalances.length;
        uint256 userDiscount = 0;
        if (tiers != 0) {
            for (uint256 i; i < tiers;) {
                uint256 balance = IERC20(xSyk).balanceOf(userAddress);
                if (balance >= xSykBalances[i]) {
                    userDiscount = discounts[i];
                } else {
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        }

        volatility = volatility.mul(1e4 - userDiscount).div(1e4);

        return volatility;
    }
}
