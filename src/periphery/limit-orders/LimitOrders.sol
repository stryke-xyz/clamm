// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

// Interfaces
import {IOptionMarket} from "../../interfaces/IOptionMarket.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IValidator} from "../../interfaces/IValidator.sol";
import {ILimitOrders} from "../../interfaces/ILimitOrders.sol";

// Libraries
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {OrderLib} from "./OrderLib.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

// Contracts
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

contract LimitOrders is EIP712("Stryke Limit Orders", "1"), ReentrancyGuard, ILimitOrders, Multicall {
    using ECDSA for bytes32;
    using OrderLib for Order;
    using SafeERC20 for IERC20;
    using TickMath for int24;

    bytes32 constant _ORDER_TYPEHASH =
        keccak256("Order(uint256 createdAt,uint256 deadline,address maker,address validator,uint32 flags,bytes data)");

    mapping(bytes32 => bool) public isOrderCancelled;

    error LimitOrders__VerificationFailed();
    error LimitOrders__OrderCancelled();
    error LimitOrders__OrderExpired();
    error LimitOrders__OrderRequirementsNotMet();
    error LimitOrders__InvalidFullfillment();
    error LimitOrders__SignerOrderMismatch();

    event LogFillOffer(Order order, address executor);
    event LogOrdersMatched(Order makerOrder, Order takerOrder, uint256 comission, address executor);
    event LogPurchasedOrderFilled(Order order, uint256 comission, address executor);
    event LogExerciseOrderFilled(Order order, uint256 comission, address executor);
    event LogOrderCancelled(Order order);

    /**
     * @notice Fills a purchase order that has OTC flag enabled
     * @param _order Order struct
     * @param _signature Signature struct
     */
    function fillOffer(Order memory _order, Signature calldata _signature)
        external
        onFullfillment(_order, _signature)
    {
        if (!_order.hasSellOptionsWithOtcFlags()) revert LimitOrders__InvalidFullfillment();

        BlockTradeOrder memory blockTradeOrder = abi.decode(_order.data, (BlockTradeOrder));

        if (blockTradeOrder.taker != address(0) && msg.sender != blockTradeOrder.taker) {
            revert LimitOrders__OrderRequirementsNotMet();
        }

        blockTradeOrder.token.safeTransferFrom(msg.sender, _order.maker, blockTradeOrder.payment);
        blockTradeOrder.optionMarket.transferFrom(_order.maker, msg.sender, blockTradeOrder.tokenId);

        emit LogFillOffer(_order, msg.sender);
    }

    /**
     * @notice Matches two otc orders with each other
     * @param _makerOrder Order struct
     * @param _takerOrder Order struct
     * @param _makerSignature Signature struct
     * @param _takerSignature Signature struct
     * @return comission for fullfilling suitable orders
     */
    function matchOrders(
        Order calldata _makerOrder,
        Order calldata _takerOrder,
        Signature calldata _makerSignature,
        Signature calldata _takerSignature
    ) external nonReentrant returns (uint256 comission) {
        if (!(_makerOrder.hasSellOptionsWithOtcFlags() && _takerOrder.hasBuyOptionsWithOtcFlags())) {
            revert LimitOrders__InvalidFullfillment();
        }

        _beforeFullFillment(_makerOrder, _makerSignature);
        _beforeFullFillment(_takerOrder, _takerSignature);

        PurchaseOrder memory purchaseOrder = abi.decode(_takerOrder.data, (PurchaseOrder));
        BlockTradeOrder memory blockTradeOrder = abi.decode(_makerOrder.data, (BlockTradeOrder));
        IOptionMarket.OptionData memory opData = blockTradeOrder.optionMarket.opData(blockTradeOrder.tokenId);

        uint256 totalLiquidity = 0;
        for (uint256 i; i < opData.opTickArrayLen; i++) {
            totalLiquidity += blockTradeOrder.optionMarket.opTickMap(blockTradeOrder.tokenId, i).liquidityToUse;
        }

        if (
            (purchaseOrder.isCall ? purchaseOrder.optionMarket.callAsset() : purchaseOrder.optionMarket.putAsset())
                != address(blockTradeOrder.token)
        ) {
            revert LimitOrders__OrderRequirementsNotMet();
        }

        if (blockTradeOrder.taker != address(0) && msg.sender != blockTradeOrder.taker) {
            revert LimitOrders__OrderRequirementsNotMet();
        }

        if (
            totalLiquidity != purchaseOrder.liquidity || opData.tickLower != purchaseOrder.tickLower
                || opData.tickUpper != purchaseOrder.tickUpper || opData.isCall != purchaseOrder.isCall
                || purchaseOrder.maxCostAllowance < blockTradeOrder.payment
                || opData.expiry < block.timestamp + purchaseOrder.ttlThreshold
                || address(blockTradeOrder.optionMarket) != address(purchaseOrder.optionMarket)
        ) {
            revert LimitOrders__OrderRequirementsNotMet();
        }

        blockTradeOrder.token.safeTransferFrom(_takerOrder.maker, _makerOrder.maker, blockTradeOrder.payment);
        blockTradeOrder.optionMarket.transferFrom(_makerOrder.maker, _takerOrder.maker, blockTradeOrder.tokenId);

        if (msg.sender != _makerOrder.maker || msg.sender != _takerOrder.maker) {
            blockTradeOrder.token.safeTransferFrom(_takerOrder.maker, msg.sender, purchaseOrder.comission);
        }

        _afterFullFillment(_makerOrder);
        _afterFullFillment(_takerOrder);

        emit LogOrdersMatched(_makerOrder, _takerOrder, purchaseOrder.comission, msg.sender);
    }

    /**
     * @notice Fills a purchase order that has market flag enabled
     * @param _order Order struct
     * @param _signature Signature struct
     * @param _opTicks OptionTicks array
     * @return cache comission for filling the order
     */
    function purchaseOption(
        Order memory _order,
        Signature calldata _signature,
        IOptionMarket.OptionTicks[] calldata _opTicks
    ) external onFullfillment(_order, _signature) nonReentrant returns (uint256 cache) {
        // Ensure order has market fill flag
        if (!_order.hasBuyOptionsWithMarketFillFlags()) revert LimitOrders__InvalidFullfillment();

        PurchaseOrder memory purchaseOrder = abi.decode(_order.data, (PurchaseOrder));

        cache = 0;

        for (uint256 i; i < _opTicks.length; i++) {
            cache += _opTicks[i].liquidityToUse;
        }

        if (cache != purchaseOrder.liquidity) {
            revert LimitOrders__OrderRequirementsNotMet();
        }

        IERC20 premiumToken = IERC20(
            purchaseOrder.isCall ? purchaseOrder.optionMarket.callAsset() : purchaseOrder.optionMarket.putAsset()
        );

        premiumToken.safeTransferFrom(_order.maker, address(this), purchaseOrder.maxCostAllowance);
        premiumToken.safeTransferFrom(_order.maker, msg.sender, purchaseOrder.comission);

        cache = premiumToken.balanceOf(address(this));

        IOptionMarket.OptionParams memory _mintOptionParams = IOptionMarket.OptionParams({
            optionTicks: _opTicks,
            tickLower: purchaseOrder.tickLower,
            tickUpper: purchaseOrder.tickUpper,
            ttl: purchaseOrder.ttl,
            isCall: purchaseOrder.isCall,
            maxCostAllowance: purchaseOrder.maxCostAllowance
        });

        uint256 optionId = purchaseOrder.optionMarket.optionIds() + 1;

        premiumToken.safeIncreaseAllowance(address(purchaseOrder.optionMarket), purchaseOrder.maxCostAllowance);
        purchaseOrder.optionMarket.mintOption(_mintOptionParams);
        purchaseOrder.optionMarket.transferFrom(address(this), _order.maker, optionId);

        // Below code assumes mintOption only deducts premium token and does not send any to this contract
        cache = cache - premiumToken.balanceOf(address(this));

        if (cache < purchaseOrder.maxCostAllowance) {
            premiumToken.safeTransfer(_order.maker, purchaseOrder.maxCostAllowance - cache);
        }

        cache = purchaseOrder.comission;

        emit LogPurchasedOrderFilled(_order, cache, msg.sender);
    }

    /**
     * @notice Fills a exercise order that has market flag enabled
     * @param _order Order struct
     * @param _signature Signature struct
     * @param _swapData  Swap route and data for exercising the options
     * @return cache for filling the order
     */
    function exerciseOption(
        Order memory _order,
        Signature calldata _signature,
        ExerciseOptionsSwapData calldata _swapData
    ) external onFullfillment(_order, _signature) nonReentrant returns (uint256 cache) {
        (uint256 minProfit, uint256 tokenId, IOptionMarket optionMarket) =
            abi.decode(_order.data, (uint256, uint256, IOptionMarket));

        // Ensure order has market fill flag and token id matches with the order
        if (!_order.hasSellOptionsWithMarketFillFlags()) {
            revert LimitOrders__InvalidFullfillment();
        }

        bool isAmount0 = optionMarket.opData(tokenId).isCall
            ? optionMarket.primePool().token0() == optionMarket.callAsset()
            : optionMarket.primePool().token0() == optionMarket.putAsset();

        uint256 amountReq;
        cache = optionMarket.opData(tokenId).opTickArrayLen;

        IOptionMarket.OptionTicks memory opTicks;

        uint256[] memory liquidityToExercise = new uint256[](cache);

        for (uint256 i; i < cache;) {
            opTicks = optionMarket.opTickMap(tokenId, i);

            amountReq = isAmount0
                ? LiquidityAmounts.getAmount1ForLiquidity(
                    opTicks.tickLower.getSqrtRatioAtTick(),
                    opTicks.tickUpper.getSqrtRatioAtTick(),
                    uint128(opTicks.liquidityToUse)
                )
                : LiquidityAmounts.getAmount0ForLiquidity(
                    opTicks.tickLower.getSqrtRatioAtTick(),
                    opTicks.tickUpper.getSqrtRatioAtTick(),
                    uint128(opTicks.liquidityToUse)
                );

            if (amountReq != 0) {
                liquidityToExercise[i] = opTicks.liquidityToUse;
            }

            unchecked {
                ++i;
            }
        }

        // check for outdated ownership
        if (optionMarket.ownerOf(tokenId) != _order.maker) revert LimitOrders__VerificationFailed();

        IOptionMarket.AssetsCache memory assetsCache = IOptionMarket(optionMarket).exerciseOption(
            IOptionMarket.ExerciseOptionParams({
                optionId: tokenId,
                swapper: _swapData.swapper,
                swapData: _swapData.swapData,
                liquidityToExercise: liquidityToExercise
            })
        );

        if (assetsCache.totalProfit < minProfit) revert LimitOrders__OrderRequirementsNotMet();

        cache = assetsCache.totalProfit - minProfit;

        if (cache > 0) {
            IERC20(address(assetsCache.assetToGet)).safeTransfer(msg.sender, cache);
        }

        IERC20(address(assetsCache.assetToGet)).safeTransfer(_order.maker, minProfit);

        emit LogExerciseOrderFilled(_order, cache, msg.sender);
    }

    /**
     * @notice Cancels an order
     * @param _order Order struct
     * @param _signature Signature struct
     */
    function cancel(Order memory _order, Signature memory _signature) public {
        address signer = getOrderSigner(_order, _signature);
        if (msg.sender != signer) {
            revert LimitOrders__VerificationFailed();
        }

        isOrderCancelled[getOrderStructHash(_order)] = true;

        emit LogOrderCancelled(_order);
    }

    modifier onFullfillment(Order memory _order, Signature calldata _signature) {
        _beforeFullFillment(_order, _signature);
        _;
        _afterFullFillment(_order);
    }

    function _beforeFullFillment(Order memory _order, Signature calldata _signature) private {
        bytes32 orderHash = getOrderStructHash(_order);
        if (_order.maker != getOrderSigner(_order, _signature)) revert LimitOrders__VerificationFailed();
        if (_order.isExpired()) revert LimitOrders__OrderExpired();
        if (isOrderCancelled[orderHash]) revert LimitOrders__OrderCancelled();
        if (_order.validator != address(0)) {
            IValidator(_order.validator).beforeFullfillment(_order);
        }
    }

    function _afterFullFillment(Order memory _order) private {
        bytes32 orderHash = getOrderStructHash(_order);

        if (_order.validator != address(0)) {
            IValidator(_order.validator).afterFullfillment(_order);
        }
        isOrderCancelled[orderHash] = true;
    }

    function _getPositionOwner(address optionMarket, uint256 tokenId) internal view returns (address owner) {
        owner = IOptionMarket(optionMarket).ownerOf(tokenId);
    }

    // functions
    function onERC721Received(address, address, uint256, bytes memory) external view returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function getOrderSigner(Order memory _order, Signature memory _signature) public view returns (address) {
        return computeDigest(_order).recover(_signature.v, _signature.r, _signature.s);
    }

    function computeDigest(Order memory _order) public view returns (bytes32) {
        return _hashTypedDataV4(getOrderStructHash(_order));
    }

    function getOrderStructHash(Order memory _order) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _ORDER_TYPEHASH,
                _order.createdAt,
                _order.deadline,
                _order.maker,
                _order.validator,
                _order.flags,
                keccak256(abi.encodePacked(_order.data))
            )
        );
    }
}
