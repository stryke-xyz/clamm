// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IHandlerV3} from "./interfaces/IHandlerV3.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

/**
 * @title DopexV2PositionManagerV2
 * @author 0xcarrot & aercwarden
 * @dev This contract is an entry point which acts as shared interface
 * between liquidity managers (handlers) and apps utilizing the liquidity.
 * It does not store any user data, it accepts truth from the handlers.
 * Use only known Handler! Be Safe!
 */
contract DopexV2PositionManagerV2 is Ownable, ReentrancyGuard, Multicall {
    using SafeERC20 for IERC20;

    mapping(bytes32 => bool) public whitelistedHandlersWithApp;
    mapping(address => bool) public whitelistedHandlers;

    // events
    event LogMintPosition(IHandlerV3 _handler, uint256 tokenId, address user, uint256 sharesMinted);

    event LogBurnPosition(IHandlerV3 _handler, uint256 tokenId, address user, uint256 sharesBurned);

    event LogUsePosition(IHandlerV3 _handler, uint256 liquidityUsed);

    event LogUnusePosition(IHandlerV3 _handler, uint256 liquidityUnused);

    event LogDonation(IHandlerV3 _handler, uint256 liquidityDonated);

    event LogUpdateWhitelistHandlerWithApp(address _handler, address _app, bool _status);

    event LogUpdateWhitelistHandler(address _handler, bool _status);

    // errors
    error StrykePositionManager__NotWhitelistedApp();
    error StrykePositionManager__NotWhitelistedHandler();

    modifier onlyWhitelistedHandlersWithApps(IHandlerV3 _handler) {
        if (!whitelistedHandlersWithApp[keccak256(abi.encode(address(_handler), msg.sender))]) {
            revert StrykePositionManager__NotWhitelistedApp();
        }
        _;
    }

    modifier onlyWhitelistedHandlers(IHandlerV3 _handler) {
        if (!whitelistedHandlers[address(_handler)]) {
            revert StrykePositionManager__NotWhitelistedHandler();
        }
        _;
    }

    /**
     * @notice Mint a new position using the specified handler.
     * @param _handler The address of the handler to use.
     * @param _mintPositionData The data required to mint the position.
     * @return sharesMinted The number of shares minted.
     */
    function mintPosition(IHandlerV3 _handler, bytes calldata _mintPositionData)
        external
        onlyWhitelistedHandlers(_handler)
        nonReentrant
        returns (uint256 sharesMinted)
    {
        uint256 tokenId = _handler.getHandlerIdentifier(_mintPositionData);

        (address[] memory tokens, uint256[] memory amounts) = _handler.tokensToPullForMint(_mintPositionData);

        uint256 amount;
        for (uint256 i; i < tokens.length; i++) {
            amount = amounts[i];
            if (amount != 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amount);
                IERC20(tokens[i]).safeIncreaseAllowance(address(_handler), amount);
            }
        }

        sharesMinted = _handler.mintPositionHandler(msg.sender, _mintPositionData);

        emit LogMintPosition(_handler, tokenId, msg.sender, sharesMinted);
    }

    /**
     * @notice Burn an existing position using the specified handler.
     * @param _handler The address of the handler to use.
     * @param _burnPositionData The data required to burn the position.
     * @return sharesBurned The number of shares burned.
     */
    function burnPosition(IHandlerV3 _handler, bytes calldata _burnPositionData)
        external
        onlyWhitelistedHandlers(_handler)
        nonReentrant
        returns (uint256 sharesBurned)
    {
        uint256 tokenId = _handler.getHandlerIdentifier(_burnPositionData);

        sharesBurned = _handler.burnPositionHandler(msg.sender, _burnPositionData);

        emit LogBurnPosition(_handler, tokenId, msg.sender, sharesBurned);
    }

    /**
     * @notice Use an existing position using the specified handler.
     * @param _handler The address of the handler to use.
     * @param _usePositionData The data required to use the position.
     * @return tokens The tokens that will be unwrapped
     * @return amounts The amounts that will be received
     * @return liquidityUsed Amount of liquidity used
     */
    function usePosition(IHandlerV3 _handler, bytes calldata _usePositionData)
        external
        onlyWhitelistedHandlersWithApps(_handler)
        nonReentrant
        returns (address[] memory tokens, uint256[] memory amounts, uint256 liquidityUsed)
    {
        (tokens, amounts, liquidityUsed) = _handler.usePositionHandler(_usePositionData);

        uint256 amount;
        for (uint256 i; i < tokens.length; i++) {
            amount = amounts[i];
            if (amount != 0) {
                IERC20(tokens[i]).safeTransfer(msg.sender, amount);
            }
        }

        emit LogUsePosition(_handler, liquidityUsed);
    }

    /**
     * @notice Unuse an existing position using the specified handler.
     * @param _handler The address of the handler to use.
     * @param _unusePositionData The data required to unuse the position.
     * @return amounts The  amounts returned
     * @return liquidity The total liquidity unused.
     */
    function unusePosition(IHandlerV3 _handler, bytes calldata _unusePositionData)
        external
        onlyWhitelistedHandlersWithApps(_handler)
        nonReentrant
        returns (uint256[] memory amounts, uint256 liquidity)
    {
        (address[] memory tokens, uint256[] memory a) = _handler.tokensToPullForUnUse(_unusePositionData);

        uint256 amount;
        for (uint256 i; i < tokens.length; i++) {
            amount = a[i];
            if (amount != 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amount);
                IERC20(tokens[i]).safeIncreaseAllowance(address(_handler), amount);
            }
        }
        (amounts, liquidity) = _handler.unusePositionHandler(_unusePositionData);

        emit LogUnusePosition(_handler, liquidity);
    }

    /**
     * @notice Donate to an existing position using the specified handler.
     * @param _handler The address of the handler to use.
     * @param _donatePosition The data required to donate to the position.
     * @return amounts The tokens and amounts donated.
     * @return liquidity The total liquidity donated.
     */
    function donateToPosition(IHandlerV3 _handler, bytes calldata _donatePosition)
        external
        onlyWhitelistedHandlersWithApps(_handler)
        nonReentrant
        returns (uint256[] memory amounts, uint256 liquidity)
    {
        (address[] memory tokens, uint256[] memory a) = _handler.tokensToPullForDonate(_donatePosition);

        uint256 amount;
        for (uint256 i; i < tokens.length; i++) {
            amount = a[i];
            if (amount != 0) {
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), amount);
                IERC20(tokens[i]).safeIncreaseAllowance(address(_handler), amount);
            }
        }
        (amounts, liquidity) = _handler.donateToPosition(_donatePosition);

        emit LogDonation(_handler, liquidity);
    }

    function reserveLiquidity(IHandlerV3 _handler, bytes calldata _reserveLiquidityData)
        external
        onlyWhitelistedHandlers(_handler)
        nonReentrant
    {
        _handler.reserveLiquidity(msg.sender, _reserveLiquidityData);
    }

    function withdrawReserveLiquidity(IHandlerV3 _handler, bytes calldata _withdrawReserveLiquidityData)
        external
        onlyWhitelistedHandlers(_handler)
        nonReentrant
    {
        _handler.reserveLiquidity(msg.sender, _withdrawReserveLiquidityData);
    }

    /**
     * @notice Update the whitelist status of a handler for a specific app.
     * @dev Only owner can call this function
     * @param _handler The address of the handler.
     * @param _app The address of the app.
     * @param _status The new whitelist status.
     */
    function updateWhitelistHandlerWithApp(address _handler, address _app, bool _status) external onlyOwner {
        whitelistedHandlersWithApp[keccak256(abi.encode(_handler, _app))] = _status;

        emit LogUpdateWhitelistHandlerWithApp(_handler, _app, _status);
    }

    /**
     * @notice Update the whitelist status of a handler.
     * @dev Only owner can call this function
     * @param _handler The address of the handler.
     * @param _status The new whitelist status.
     */
    function updateWhitelistHandler(address _handler, bool _status) external onlyOwner {
        whitelistedHandlers[_handler] = _status;

        emit LogUpdateWhitelistHandler(_handler, _status);
    }
}
