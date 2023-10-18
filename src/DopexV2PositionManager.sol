// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IHandler} from "./interfaces/IHandler.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

contract DopexV2PositionManager is Ownable, ReentrancyGuard, Multicall {
    using SafeERC20 for IERC20;
    mapping(bytes32 => bool) public whitelistedHandlersWithApp;
    mapping(address => bool) public whitelistedHandlers;

    // events
    event LogMintPosition(
        IHandler _handler,
        uint256 tokenId,
        address user,
        uint256 sharesMinted
    );

    event LogBurnPosition(
        IHandler _handler,
        uint256 tokenId,
        address user,
        uint256 sharesBurned
    );

    event LogUsePosition(IHandler _handler, uint256 liquidityUsed);

    event LogUnusePosition(IHandler _handler, uint256 liquidityUnused);

    event LogDonation(IHandler _handler, uint256 liquidityDonated);

    event LogUpdateWhitelistHandlerWithApp(
        address _handler,
        address _app,
        bool _status
    );

    event LogUpdateWhitelistHandler(address _handler, bool _status);

    // errors
    error DopexV2PositionManager__NotWhitelistedApp();
    error DopexV2PositionManager__NotWhitelistedHandler();

    modifier onlyWhitelistedHandlersWithApps(IHandler _handler) {
        if (
            !whitelistedHandlersWithApp[
                keccak256(abi.encode(address(_handler), msg.sender))
            ]
        ) revert DopexV2PositionManager__NotWhitelistedApp();
        _;
    }

    modifier onlyWhitelistedHandlers(IHandler _handler) {
        if (!whitelistedHandlers[address(_handler)])
            revert DopexV2PositionManager__NotWhitelistedHandler();
        _;
    }

    function mintPosition(
        IHandler _handler,
        bytes calldata _mintPositionData
    )
        external
        onlyWhitelistedHandlers(_handler)
        nonReentrant
        returns (uint256 sharesMinted)
    {
        uint256 tokenId = _handler.getHandlerIdentifier(_mintPositionData);

        (address[] memory tokens, uint256[] memory amounts) = _handler
            .tokensToPullForMint(_mintPositionData);

        for (uint256 i; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(
                msg.sender,
                address(this),
                amounts[i]
            );
            IERC20(tokens[i]).safeApprove(address(_handler), amounts[i]);
        }

        sharesMinted = _handler.mintPositionHandler(
            msg.sender,
            _mintPositionData
        );

        emit LogMintPosition(_handler, tokenId, msg.sender, sharesMinted);
    }

    function burnPosition(
        IHandler _handler,
        bytes calldata _burnPositionData
    )
        external
        onlyWhitelistedHandlers(_handler)
        nonReentrant
        returns (uint256 sharesBurned)
    {
        uint256 tokenId = _handler.getHandlerIdentifier(_burnPositionData);

        sharesBurned = _handler.burnPositionHandler(
            msg.sender,
            _burnPositionData
        );

        emit LogBurnPosition(_handler, tokenId, msg.sender, sharesBurned);
    }

    function usePosition(
        IHandler _handler,
        bytes calldata _usePositionData
    )
        external
        onlyWhitelistedHandlersWithApps(_handler)
        returns (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 liquidityUsed
        )
    {
        (tokens, amounts, liquidityUsed) = _handler.usePositionHandler(
            _usePositionData
        );

        for (uint256 i; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(msg.sender, amounts[i]);
        }

        emit LogUsePosition(_handler, liquidityUsed);
    }

    function unusePosition(
        IHandler _handler,
        bytes calldata _unusePositionData
    )
        external
        onlyWhitelistedHandlersWithApps(_handler)
        returns (uint256[] memory amounts, uint256 liquidity)
    {
        (address[] memory tokens, uint256[] memory a) = _handler
            .tokensToPullForUnUse(_unusePositionData);

        for (uint256 i; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), a[i]);
            IERC20(tokens[i]).safeApprove(address(_handler), a[i]);
        }
        (amounts, liquidity) = _handler.unusePositionHandler(
            _unusePositionData
        );

        emit LogUnusePosition(_handler, liquidity);
    }

    function donateToPosition(
        IHandler _handler,
        bytes calldata _donatePosition
    )
        external
        onlyWhitelistedHandlersWithApps(_handler)
        returns (uint256[] memory amounts, uint256 liquidity)
    {
        (address[] memory tokens, uint256[] memory a) = _handler
            .tokensToPullForDonate(_donatePosition);

        for (uint256 i; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), a[i]);
            IERC20(tokens[i]).safeApprove(address(_handler), a[i]);
        }
        (amounts, liquidity) = _handler.donateToPosition(_donatePosition);

        emit LogDonation(_handler, liquidity);
    }

    // whitelist functions
    function updateWhitelistHandlerWithApp(
        address _handler,
        address _app,
        bool _status
    ) external onlyOwner {
        whitelistedHandlersWithApp[
            keccak256(abi.encode(_handler, _app))
        ] = _status;

        emit LogUpdateWhitelistHandlerWithApp(_handler, _app, _status);
    }

    function updateWhitelistHandler(
        address _handler,
        bool _status
    ) external onlyOwner {
        whitelistedHandlers[_handler] = _status;

        emit LogUpdateWhitelistHandler(_handler, _status);
    }
}
