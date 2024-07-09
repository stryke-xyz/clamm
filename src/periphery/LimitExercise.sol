// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

// Libraries
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

// Interfaces
import {IOptionMarket} from "../interfaces/IOptionMarket.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract LimitExercise is AccessControl, EIP712, Multicall, ReentrancyGuard {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    mapping(bytes32 => bool) public cancelledOrders;

    struct Order {
        uint256 createdAt;
        uint256 optionId;
        uint256 minProfit;
        uint256 deadline;
        address profitToken;
        address optionMarket;
        address signer;
    }

    struct SignatureMeta {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    error LimitExercise__SignatureVerificationFailed();
    error LimitExercise__CancelledOrder();
    error LimitExercise__OrderNotSatisfied();
    error LimitExercise__OrderExpired();

    event LogLimitExerciseOrderCancelled(Order order, SignatureMeta sigMeta);
    event LogLimitExericseOrderFullfilled(Order order, uint256 executorProfit, address executor);

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 optionId,uint256 minProfit,uint256 deadline,address profitToken,address optionMarket,address signer)"
    );

    constructor() EIP712("DopexV2_Clamm_Limit_Exercise_Order", "1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(KEEPER_ROLE, msg.sender);
    }

    /**
     * @notice                Execute a limit exercise order. Reverts
     *                        if order is not fullfilled properly or
     *                        signature verification fails.
     * @param _order          Order details as specified on signing.
     * @param _signatureMeta  Signature meta as specified on signing.
     * @param _exerciseParams Parameters for exercising the option.
     *                        (refer to DopexV2OptionMarket.exercseOption)
     * @return executorProfit Profit received by the executor in relevant
     *                        token precision.
     */
    function limitExercise(
        Order calldata _order,
        SignatureMeta calldata _signatureMeta,
        IOptionMarket.ExerciseOptionParams calldata _exerciseParams
    ) external nonReentrant onlyRole(KEEPER_ROLE) returns (uint256 executorProfit) {
        IOptionMarket optionMarket = IOptionMarket(_order.optionMarket);

        if (_order.deadline <= block.timestamp) revert LimitExercise__OrderExpired();

        // Should verify signature in general and should also revert incase the limit order was placed by a signer different than the owner.
        if (!verify(_order, _signatureMeta)) {
            revert LimitExercise__SignatureVerificationFailed();
        }

        // Avoid cancelled orders
        if (cancelledOrders[getOrderSigHash(_order, _signatureMeta)]) {
            revert LimitExercise__CancelledOrder();
        }

        optionMarket.exerciseOption(_exerciseParams);

        uint256 tokenBalance = IERC20(_order.profitToken).balanceOf(address(this));

        if (tokenBalance >= _order.minProfit) {
            executorProfit = tokenBalance - _order.minProfit;

            // Transfer executor's delta to msg.sender
            if (executorProfit > 0) {
                IERC20(_order.profitToken).safeTransfer(msg.sender, executorProfit);
            }

            // Transfer options owner's delta
            IERC20(_order.profitToken).safeTransfer(optionMarket.ownerOf(_exerciseParams.optionId), _order.minProfit);

            // Cancel the order to avoid re-using the order
            cancelledOrders[getOrderSigHash(_order, _sigMeta)] = true;

            emit LogLimitExericseOrderFullfilled(_order, executorProfit, msg.sender);
        } else {
            revert LimitExercise__OrderNotSatisfied();
        }
    }

    /**
     * @notice         Nullify an limit exercise order signature.
     * @param _order   Order details as specified on signing.
     * @param _sigMeta Signature meta as specified on signing.
     */
    function cancelOrder(Order calldata _order, SignatureMeta calldata _sigMeta) external {
        if (_order.signer != msg.sender) {
            revert LimitExercise__SignatureVerificationFailed();
        }

        cancelledOrders[getOrderSigHash(_order, _sigMeta)] = true;

        emit LogLimitExerciseOrderCancelled(_order, _sigMeta);
    }

    function getOrderSigHash(Order calldata _order, SignatureMeta calldata _sigMeta) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                _order.createdAt,
                _order.optionId,
                _order.minProfit,
                _order.deadline,
                _order.profitToken,
                _order.optionMarket,
                _order.signer,
                _sigMeta.v,
                _sigMeta.r,
                _sigMeta.s
            )
        );
    }

    /**
     * @notice
     *  @param  _order         Limit exercise order information.
     *  @param  _signatureMeta V, R, S of the signature.
     *  @return verified       Whether signature was signed by
     *                         signer specified in the order &
     *                         signer is owner of the options position.
     */
    function verify(Order calldata _order, SignatureMeta calldata _signatureMeta) public view returns (bool) {
        bytes32 digest = computeDigest(_order);

        return IOptionMarket(_order.optionMarket).ownerOf(_order.optionId)
            == digest.recover(_signatureMeta.v, _signatureMeta.r, _signatureMeta.s);
    }

    function getStructHash(Order calldata _order) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                _order.createdAt,
                _order.optionId,
                _order.minProfit,
                _order.deadline,
                _order.profitToken,
                _order.optionMarket,
                _order.signer
            )
        );
    }

    function computeDigest(Order calldata _order) public view returns (bytes32) {
        return _hashTypedDataV4(getStructHash(_order));
    }
}
