// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

// Libraries
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Interfaces
import {IOptionMarket} from "../interfaces/IOptionMarket.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract LimitExercise is AccessControl, EIP712 {
    using ECDSA for bytes32;

    struct Order {
        uint256 optionId;
        uint256 minProfit;
        uint256 deadline;
    }

    struct SignatureMeta {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event LimitOrderExercise_LimitExercise(
        uint256 optionId,
        uint256 optionOwnerProfit,
        uint256 executorProfit,
        IERC20 profitToken,
        IOptionMarket optionMarket
    );

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant ORDER_TYPEHASH =
        keccak256("Order(uint256 optionId,uint256 minProfit,uint256 deadline)");

    constructor() EIP712("LimitExercise", "1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KEEPER_ROLE, msg.sender);
    }

    function limitExercise(
        address _extraProfitTo,
        IOptionMarket optionMarket,
        Order calldata _order,
        SignatureMeta calldata _signatureMeta,
        IOptionMarket.ExerciseOptionParams calldata _exerciseParams
    ) external onlyRole(KEEPER_ROLE) {
        require(
            _order.optionId == _exerciseParams.optionId,
            "optionIds don't match"
        );
        require(_order.minProfit != 0, "minProfit is zero");
        require(_order.deadline <= block.timestamp, "Order Expired");
        // Should verify signature in general and should also revert incase the limit order was placed by a signer different than the owner.
        require(
            verify(
                optionMarket.ownerOf(_exerciseParams.optionId),
                _order,
                _signatureMeta
            ),
            "Unable to verify signature"
        );

        bool isCall = optionMarket.opData(_exerciseParams.optionId).isCall;

        IERC20 tokenInContext = isCall
            ? IERC20(optionMarket.putAsset())
            : IERC20(optionMarket.callAsset());

        uint256 tokenBalance = tokenInContext.balanceOf(address(this));

        optionMarket.exerciseOption(_exerciseParams);

        tokenBalance = tokenInContext.balanceOf(address(this)) - tokenBalance;

        if (tokenBalance >= 0) {
            uint256 executorProfit = tokenBalance > _order.minProfit
                ? tokenBalance - _order.minProfit
                : 0;

            uint256 userProfit = executorProfit > 0
                ? _order.minProfit
                : tokenBalance;

            // transfer complete profit if its above min profit or transfer min profit and extra to provided address
            if (executorProfit > 0) {
                tokenInContext.transfer(_extraProfitTo, executorProfit);
            }

            if (userProfit > 0) {
                tokenInContext.transfer(
                    optionMarket.ownerOf(_exerciseParams.optionId),
                    userProfit
                );
            }

            emit LimitOrderExercise_LimitExercise(
                _exerciseParams.optionId,
                userProfit,
                executorProfit,
                tokenInContext,
                optionMarket
            );
        }
    }

    // Signature utils

    function verify(
        address _signer,
        Order calldata _order,
        SignatureMeta calldata _signatureMeta
    ) public view returns (bool) {
        bytes32 digest = computeDigest(_order);

        return
            _signer ==
            digest.recover(
                _signatureMeta.v,
                _signatureMeta.r,
                _signatureMeta.s
            );
    }

    function getStructHash(
        Order calldata _order
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    _order.optionId,
                    _order.minProfit,
                    _order.deadline
                )
            );
    }

    function computeDigest(
        Order calldata _order
    ) public view returns (bytes32) {
        return _hashTypedDataV4(getStructHash(_order));
    }
}
