// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IDopexV2PositionManager} from "./interfaces/IDopexV2PositionManager.sol";

import {IOptionPricingV2} from "./pricing/IOptionPricingV2.sol";
import {IHandler} from "./interfaces/IHandler.sol";
import {IDopexV2ClammFeeStrategyV2} from "./pricing/fees/IDopexV2ClammFeeStrategyV2.sol";
import {ISwapper} from "./interfaces/ISwapper.sol";
import {ITokenURIFetcher} from "./interfaces/ITokenURIFetcher.sol";

import {ERC721} from "./ERC721.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

/**
 * @title DopexV2OptionMarketV2
 * @author 0xcarrot
 * @dev Allow traders to buy CALL and PUT options using CLAMM liquidity, which can be
 * exercised at any time ITM.
 */
contract DopexV2OptionMarketV2 is ReentrancyGuard, Multicall, Ownable, ERC721 {
    using TickMath for int24;

    struct OptionData {
        uint256 opTickArrayLen;
        int24 tickLower;
        int24 tickUpper;
        uint256 expiry;
        bool isCall;
    }

    struct OptionTicks {
        IHandler _handler;
        IUniswapV3Pool pool;
        address hook;
        int24 tickLower;
        int24 tickUpper;
        uint256 liquidityToUse;
    }

    struct OptionParams {
        OptionTicks[] optionTicks;
        int24 tickLower;
        int24 tickUpper;
        uint256 ttl;
        bool isCall;
        uint256 maxCostAllowance;
    }

    struct ExerciseOptionParams {
        uint256 optionId;
        ISwapper[] swapper;
        bytes[] swapData;
        uint256[] liquidityToExercise;
    }

    struct SettleOptionParams {
        uint256 optionId;
        ISwapper[] swapper;
        bytes[] swapData;
        uint256[] liquidityToSettle;
    }

    struct PositionSplitterParams {
        uint256 optionId;
        address to;
        uint256[] liquidityToSplit;
    }

    // events
    event LogMintOption(
        address user,
        uint256 tokenId,
        bool isCall,
        uint256 premiumAmount,
        uint256 totalAssetWithdrawn
    );
    event LogExerciseOption(
        address user,
        uint256 tokenId,
        uint256 totalProfit,
        uint256 totalAssetRelocked
    );
    event LogSettleOption(address user, uint256 tokenId);
    event LogSplitOption(
        address user,
        uint256 tokenId,
        uint256 newTokenId,
        address to
    );
    event LogIVSetterUpdate(address _setter, bool _status);
    event LogIVUpdate(uint256[] ttl, uint256[] iv);
    event LogUpdateExerciseDelegate(
        address owner,
        address delegate,
        bool status
    );
    event LogOptionsMarketInitialized(
        address primePool,
        address optionPricing,
        address dpFee,
        address callAsset,
        address putAsset
    );
    event LogUpdateAddress(
        address tokeURIFetcher,
        address dpFee,
        address optionPricing
    );

    // errors
    error DopexV2OptionMarket__IVNotSet();
    error DopexV2OptionMarket__NotValidStrikeTick();
    error DopexV2OptionMarket__PoolNotApproved();
    error DopexV2OptionMarket__MaxCostAllowanceExceeded();
    error DopexV2OptionMarket__NotOwnerOrDelegator();
    error DopexV2OptionMarket__EmptyOption();
    error DopexV2OptionMarket__ArrayLenMismatch();
    error DopexV2OptionMarket__OptionExpired();
    error DopexV2OptionMarket__OptionNotExpired();
    error DopexV2OptionMarket__NotEnoughAfterSwap();
    error DopexV2OptionMarket__NotApprovedSettler();
    error DopexV2OptionMarket__NotIVSetter();
    error DopexV2OptionMarket__InvalidPool();

    IDopexV2ClammFeeStrategyV2 public dpFee;
    IOptionPricingV2 public optionPricing;

    IDopexV2PositionManager public immutable positionManager;
    IUniswapV3Pool public immutable primePool;
    address public immutable callAsset;
    address public immutable putAsset;
    uint8 public immutable callAssetDecimals;
    uint8 public immutable putAssetDecimals;

    address public feeTo;
    address public tokenURIFetcher;

    mapping(uint256 => OptionData) public opData;
    mapping(uint256 => OptionTicks[]) public opTickMap;
    mapping(address => mapping(address => bool)) public exerciseDelegator;
    mapping(address => bool) public approvedPools;
    mapping(address => bool) public settlers;

    uint256 public optionIds;

    constructor(
        address _pm,
        address _optionPricing,
        address _dpFee,
        address _callAsset,
        address _putAsset,
        address _primePool
    ) {
        positionManager = IDopexV2PositionManager(_pm);
        callAsset = _callAsset;
        putAsset = _putAsset;

        dpFee = IDopexV2ClammFeeStrategyV2(_dpFee);

        optionPricing = IOptionPricingV2(_optionPricing);

        primePool = IUniswapV3Pool(_primePool);

        if (
            primePool.token0() != _callAsset && primePool.token1() != _callAsset
        ) revert DopexV2OptionMarket__InvalidPool();
        if (primePool.token0() != _putAsset && primePool.token1() != _putAsset)
            revert DopexV2OptionMarket__InvalidPool();

        callAssetDecimals = ERC20(_callAsset).decimals();
        putAssetDecimals = ERC20(_putAsset).decimals();

        emit LogOptionsMarketInitialized(
            _primePool,
            _optionPricing,
            _dpFee,
            _callAsset,
            _putAsset
        );
    }

    function name() public view override returns (string memory) {
        return "Dopex V2 Option Market V2";
    }

    function symbol() public view override returns (string memory) {
        return "DPX-V2-OMV2";
    }

    /**
     * @notice Provides the tokenURI for each token
     * @param id The token Id.
     * @return The tokenURI string data
     */
    function tokenURI(uint256 id) public view override returns (string memory) {
        return ITokenURIFetcher(tokenURIFetcher).onFetchTokenURIData(id);
    }

    /**
     * @notice Mints an option for the given strike and expiry.
     * @param _params The option  parameters.
     */
    function mintOption(OptionParams calldata _params) external nonReentrant {
        optionIds += 1;

        uint256[] memory amountsPerOptionTicks = new uint256[](
            _params.optionTicks.length
        );
        uint256 totalAssetWithdrawn;

        bool isAmount0;

        address assetToUse = _params.isCall ? callAsset : putAsset;

        OptionTicks memory opTick;

        for (uint256 i; i < _params.optionTicks.length; i++) {
            opTick = _params.optionTicks[i];
            if (
                _params.isCall
                    ? _params.tickUpper != opTick.tickUpper
                    : _params.tickLower != opTick.tickLower
            ) revert DopexV2OptionMarket__NotValidStrikeTick();

            opTickMap[optionIds].push(
                OptionTicks({
                    _handler: opTick._handler,
                    pool: opTick.pool,
                    hook: opTick.hook,
                    tickLower: opTick.tickLower,
                    tickUpper: opTick.tickUpper,
                    liquidityToUse: opTick.liquidityToUse
                })
            );

            if (!approvedPools[address(opTick.pool)])
                revert DopexV2OptionMarket__PoolNotApproved();

            bytes memory usePositionData = abi.encode(
                opTick.pool,
                opTick.hook,
                opTick.tickLower,
                opTick.tickUpper,
                opTick.liquidityToUse,
                abi.encode(
                    address(this),
                    _params.ttl,
                    _params.isCall,
                    opTick.pool,
                    opTick.tickLower,
                    opTick.tickUpper
                )
            );

            (
                address[] memory tokens,
                uint256[] memory amounts,

            ) = positionManager.usePosition(opTick._handler, usePositionData);

            if (tokens[0] == assetToUse) {
                require(amounts[0] > 0 && amounts[1] == 0);
                amountsPerOptionTicks[i] = (amounts[0]);
                totalAssetWithdrawn += amounts[0];
                isAmount0 = true;
            } else {
                require(amounts[1] > 0 && amounts[0] == 0);
                amountsPerOptionTicks[i] = (amounts[1]);
                totalAssetWithdrawn += amounts[1];
                isAmount0 = false;
            }
        }

        uint256 strike = getPricePerCallAssetViaTick(
            primePool,
            _params.isCall ? _params.tickUpper : _params.tickLower
        );

        uint256 premiumAmount = _getPremiumAmount(
            _params.isCall ? false : true, // isPut
            block.timestamp + _params.ttl, // expiry
            strike, // Strike
            getCurrentPricePerCallAsset(primePool), // Current price
            _params.isCall
                ? totalAssetWithdrawn
                : (totalAssetWithdrawn * (10 ** putAssetDecimals)) / strike
        );

        if (premiumAmount == 0) revert DopexV2OptionMarket__IVNotSet();

        uint256 protocolFees;
        if (feeTo != address(0)) {
            protocolFees = getFee(totalAssetWithdrawn, premiumAmount);
            ERC20(assetToUse).transferFrom(msg.sender, feeTo, protocolFees);
        }

        if (premiumAmount + protocolFees > _params.maxCostAllowance)
            revert DopexV2OptionMarket__MaxCostAllowanceExceeded();

        ERC20(assetToUse).transferFrom(
            msg.sender,
            address(this),
            premiumAmount
        );
        ERC20(assetToUse).approve(address(positionManager), premiumAmount);

        for (uint i; i < _params.optionTicks.length; i++) {
            opTick = _params.optionTicks[i];
            uint256 premiumAmountEarned = (amountsPerOptionTicks[i] *
                premiumAmount) / totalAssetWithdrawn;

            uint128 liquidityToDonate = LiquidityAmounts.getLiquidityForAmounts(
                _getCurrentSqrtPriceX96(opTick.pool),
                opTick.tickLower.getSqrtRatioAtTick(),
                opTick.tickUpper.getSqrtRatioAtTick(),
                isAmount0 ? premiumAmountEarned : 0,
                isAmount0 ? 0 : premiumAmountEarned
            );

            bytes memory donatePositionData = abi.encode(
                opTick.pool,
                opTick.hook,
                opTick.tickLower,
                opTick.tickUpper,
                liquidityToDonate
            );
            positionManager.donateToPosition(
                opTick._handler,
                donatePositionData
            );
        }

        opData[optionIds] = OptionData({
            opTickArrayLen: _params.optionTicks.length,
            tickLower: _params.tickLower,
            tickUpper: _params.tickUpper,
            expiry: block.timestamp + _params.ttl,
            isCall: _params.isCall
        });

        _safeMint(msg.sender, optionIds);

        emit LogMintOption(
            msg.sender,
            optionIds,
            _params.isCall,
            premiumAmount,
            totalAssetWithdrawn
        );
    }

    struct AssetsCache {
        ERC20 assetToUse;
        ERC20 assetToGet;
        uint256 totalProfit;
        uint256 totalAssetRelocked;
    }

    /**
     * @notice Exercises the given option .
     * @param _params The exercise option  parameters.
     */
    function exerciseOption(
        ExerciseOptionParams calldata _params
    ) external nonReentrant {
        if (
            ownerOf(_params.optionId) != msg.sender &&
            exerciseDelegator[ownerOf(_params.optionId)][msg.sender] == false
        ) revert DopexV2OptionMarket__NotOwnerOrDelegator();

        OptionData memory oData = opData[_params.optionId];

        if (oData.opTickArrayLen != _params.liquidityToExercise.length)
            revert DopexV2OptionMarket__ArrayLenMismatch();

        if (oData.expiry < block.timestamp)
            revert DopexV2OptionMarket__OptionExpired();

        bool isAmount0 = oData.isCall
            ? primePool.token0() == callAsset
            : primePool.token0() == putAsset;

        AssetsCache memory ac;

        ac.assetToUse = ERC20(oData.isCall ? callAsset : putAsset);
        ac.assetToGet = ERC20(oData.isCall ? putAsset : callAsset);

        for (uint256 i; i < oData.opTickArrayLen; i++) {
            OptionTicks storage opTick = opTickMap[_params.optionId][i];

            uint256 amountToSwap = isAmount0
                ? LiquidityAmounts.getAmount0ForLiquidity(
                    opTick.tickLower.getSqrtRatioAtTick(),
                    opTick.tickUpper.getSqrtRatioAtTick(),
                    uint128(_params.liquidityToExercise[i])
                )
                : LiquidityAmounts.getAmount1ForLiquidity(
                    opTick.tickLower.getSqrtRatioAtTick(),
                    opTick.tickUpper.getSqrtRatioAtTick(),
                    uint128(_params.liquidityToExercise[i])
                );

            ac.totalAssetRelocked += amountToSwap;

            uint256 prevBalance = ac.assetToGet.balanceOf(address(this));

            ac.assetToUse.transfer(address(_params.swapper[i]), amountToSwap);

            _params.swapper[i].onSwapReceived(
                address(ac.assetToUse),
                address(ac.assetToGet),
                amountToSwap,
                _params.swapData[i]
            );

            uint256 amountReq = isAmount0
                ? LiquidityAmounts.getAmount1ForLiquidity(
                    opTick.tickLower.getSqrtRatioAtTick(),
                    opTick.tickUpper.getSqrtRatioAtTick(),
                    uint128(_params.liquidityToExercise[i])
                )
                : LiquidityAmounts.getAmount0ForLiquidity(
                    opTick.tickLower.getSqrtRatioAtTick(),
                    opTick.tickUpper.getSqrtRatioAtTick(),
                    uint128(_params.liquidityToExercise[i])
                );

            uint256 currentBalance = ac.assetToGet.balanceOf(address(this));

            if (currentBalance < prevBalance + amountReq)
                revert DopexV2OptionMarket__NotEnoughAfterSwap();

            ac.assetToGet.approve(address(positionManager), amountReq);

            bytes memory unusePositionData = abi.encode(
                opTick.pool,
                opTick.hook,
                opTick.tickLower,
                opTick.tickUpper,
                _params.liquidityToExercise[i],
                abi.encode("")
            );

            positionManager.unusePosition(opTick._handler, unusePositionData);

            opTick.liquidityToUse -= _params.liquidityToExercise[i];

            ac.totalProfit += currentBalance - (prevBalance + amountReq);
        }

        ac.assetToGet.transfer(msg.sender, ac.totalProfit);

        emit LogExerciseOption(
            ownerOf(_params.optionId),
            _params.optionId,
            ac.totalProfit,
            ac.totalAssetRelocked
        );
    }

    /**
     * @notice Settles the given option .
     * @param _params The settle option  parameters.
     */
    function settleOption(
        SettleOptionParams calldata _params
    ) external nonReentrant {
        if (!settlers[msg.sender])
            revert DopexV2OptionMarket__NotApprovedSettler();
        OptionData memory oData = opData[_params.optionId];

        if (oData.opTickArrayLen != _params.liquidityToSettle.length)
            revert DopexV2OptionMarket__ArrayLenMismatch();

        if (block.timestamp <= oData.expiry)
            revert DopexV2OptionMarket__OptionNotExpired();

        bool isAmount0 = oData.isCall
            ? primePool.token0() == callAsset
            : primePool.token0() == putAsset;

        AssetsCache memory ac;

        ac.assetToUse = ERC20(oData.isCall ? callAsset : putAsset);
        ac.assetToGet = ERC20(oData.isCall ? putAsset : callAsset);

        for (uint256 i; i < oData.opTickArrayLen; i++) {
            OptionTicks storage opTick = opTickMap[_params.optionId][i];
            uint256 liquidityToSettle = _params.liquidityToSettle[i] != 0
                ? _params.liquidityToSettle[i]
                : opTick.liquidityToUse;

            (uint256 amount0, uint256 amount1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    _getCurrentSqrtPriceX96(opTick.pool),
                    opTick.tickLower.getSqrtRatioAtTick(),
                    opTick.tickUpper.getSqrtRatioAtTick(),
                    uint128(liquidityToSettle)
                );

            if (
                (amount0 > 0 && amount1 == 0) || (amount1 > 0 && amount0 == 0)
            ) {
                if (isAmount0 && amount0 > 0) {
                    ac.assetToUse.approve(address(positionManager), amount0);
                } else if (!isAmount0 && amount1 > 0) {
                    ac.assetToUse.approve(address(positionManager), amount1);
                } else {
                    uint256 amountToSwap = isAmount0
                        ? LiquidityAmounts.getAmount0ForLiquidity(
                            opTick.tickLower.getSqrtRatioAtTick(),
                            opTick.tickUpper.getSqrtRatioAtTick(),
                            uint128(liquidityToSettle)
                        )
                        : LiquidityAmounts.getAmount1ForLiquidity(
                            opTick.tickLower.getSqrtRatioAtTick(),
                            opTick.tickUpper.getSqrtRatioAtTick(),
                            uint128(liquidityToSettle)
                        );

                    uint256 prevBalance = ac.assetToGet.balanceOf(
                        address(this)
                    );

                    ac.assetToUse.transfer(
                        address(_params.swapper[i]),
                        amountToSwap
                    );

                    _params.swapper[i].onSwapReceived(
                        address(ac.assetToUse),
                        address(ac.assetToGet),
                        amountToSwap,
                        _params.swapData[i]
                    );

                    uint256 amountReq = isAmount0
                        ? LiquidityAmounts.getAmount1ForLiquidity(
                            opTick.tickLower.getSqrtRatioAtTick(),
                            opTick.tickUpper.getSqrtRatioAtTick(),
                            uint128(liquidityToSettle)
                        )
                        : LiquidityAmounts.getAmount0ForLiquidity(
                            opTick.tickLower.getSqrtRatioAtTick(),
                            opTick.tickUpper.getSqrtRatioAtTick(),
                            uint128(liquidityToSettle)
                        );

                    uint256 currentBalance = ac.assetToGet.balanceOf(
                        address(this)
                    );

                    if (currentBalance < prevBalance + amountReq)
                        revert DopexV2OptionMarket__NotEnoughAfterSwap();

                    ac.assetToGet.approve(address(positionManager), amountReq);

                    ac.assetToGet.transfer(
                        msg.sender,
                        currentBalance - (prevBalance + amountReq)
                    );
                }
            } else {
                if (isAmount0) {
                    ac.assetToUse.approve(address(positionManager), amount0);
                    ac.assetToGet.approve(address(positionManager), amount1);

                    uint256 actualAmount0 = LiquidityAmounts
                        .getAmount0ForLiquidity(
                            opTick.tickLower.getSqrtRatioAtTick(),
                            opTick.tickUpper.getSqrtRatioAtTick(),
                            uint128(liquidityToSettle)
                        );

                    ac.assetToGet.transferFrom(
                        msg.sender,
                        address(this),
                        amount1
                    );

                    ac.assetToUse.transfer(msg.sender, actualAmount0 - amount0);
                } else {
                    ac.assetToUse.approve(address(positionManager), amount1);
                    ac.assetToGet.approve(address(positionManager), amount0);

                    uint256 actualAmount1 = LiquidityAmounts
                        .getAmount1ForLiquidity(
                            opTick.tickLower.getSqrtRatioAtTick(),
                            opTick.tickUpper.getSqrtRatioAtTick(),
                            uint128(liquidityToSettle)
                        );

                    ac.assetToGet.transferFrom(
                        msg.sender,
                        address(this),
                        amount0
                    );

                    ac.assetToUse.transfer(msg.sender, actualAmount1 - amount1);
                }
            }

            bytes memory unusePositionData = abi.encode(
                opTick.pool,
                opTick.hook,
                opTick.tickLower,
                opTick.tickUpper,
                liquidityToSettle,
                abi.encode("")
            );

            positionManager.unusePosition(opTick._handler, unusePositionData);

            opTick.liquidityToUse -= liquidityToSettle;
        }

        emit LogSettleOption(ownerOf(_params.optionId), _params.optionId);
    }

    /**
     * @notice Splits the given option into a new option.
     * @param _params The position splitter parameters.
     */
    function positionSplitter(
        PositionSplitterParams calldata _params
    ) external nonReentrant {
        optionIds += 1;

        if (ownerOf(_params.optionId) != msg.sender)
            revert DopexV2OptionMarket__NotOwnerOrDelegator();
        OptionData memory oData = opData[_params.optionId];

        if (oData.opTickArrayLen != _params.liquidityToSplit.length)
            revert DopexV2OptionMarket__ArrayLenMismatch();

        for (uint256 i; i < _params.liquidityToSplit.length; i++) {
            if (_params.liquidityToSplit[i] == 0)
                revert DopexV2OptionMarket__EmptyOption();
            OptionTicks storage opTick = opTickMap[_params.optionId][i];
            opTick.liquidityToUse -= _params.liquidityToSplit[i];

            opTickMap[optionIds].push(
                OptionTicks({
                    _handler: opTick._handler,
                    pool: opTick.pool,
                    hook: opTick.hook,
                    tickLower: opTick.tickLower,
                    tickUpper: opTick.tickUpper,
                    liquidityToUse: _params.liquidityToSplit[i]
                })
            );
        }

        opData[optionIds] = OptionData({
            opTickArrayLen: _params.liquidityToSplit.length,
            tickLower: oData.tickLower,
            tickUpper: oData.tickUpper,
            expiry: oData.expiry,
            isCall: oData.isCall
        });

        _safeMint(_params.to, optionIds);

        emit LogSplitOption(
            ownerOf(_params.optionId),
            _params.optionId,
            optionIds,
            _params.to
        );
    }

    /**
     * @notice Updates the exercise delegate for the caller's option.
     * @param _delegateTo The address of the new exercise delegate.
     * @param _status The status of the exercise delegate (true to enable, false to disable).
     */
    function updateExerciseDelegate(
        address _delegateTo,
        bool _status
    ) external {
        exerciseDelegator[msg.sender][_delegateTo] = _status;
        emit LogUpdateExerciseDelegate(msg.sender, _delegateTo, _status);
    }

    // internal
    /**
     * @notice Calculates the price per call asset for the given tick.
     * @param _pool The UniswapV3 pool.
     * @param _tick The tick.
     * @return The price per call asset.
     */
    function getPricePerCallAssetViaTick(
        IUniswapV3Pool _pool,
        int24 _tick
    ) public view returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(_tick);
        return _getPrice(_pool, sqrtPriceX96);
    }

    /**
     * @notice Calculates the current price per call asset.
     * @param _pool The UniswapV3 pool.
     * @return The current price per call asset.
     */
    function getCurrentPricePerCallAsset(
        IUniswapV3Pool _pool
    ) public view returns (uint256) {
        (uint160 sqrtPriceX96, , , , , , ) = _pool.slot0();
        return _getPrice(_pool, sqrtPriceX96);
    }

    /**
     * @notice Calculates the premium amount for the given option parameters.
     * @param isPut Whether the option is a put or call.
     * @param expiry The expiry of the option.
     * @param strike The strike price of the option.
     * @param lastPrice The last price of the underlying asset.
     * @param amount The amount of the underlying asset.
     * @return The premium amount.
     */
    function getPremiumAmount(
        bool isPut,
        uint expiry,
        uint strike,
        uint lastPrice,
        uint amount
    ) external view returns (uint256) {
        return _getPremiumAmount(isPut, expiry, strike, lastPrice, amount);
    }

    /**
     * @notice Gets the current sqrt price.
     * @param pool The UniswapV3 pool.
     * @return sqrtPriceX96 The current sqrt price.
     */
    function _getCurrentSqrtPriceX96(
        IUniswapV3Pool pool
    ) internal view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96, , , , , , ) = pool.slot0();
    }

    /**
     * @notice Calculates the premium amount for the given option parameters.
     * @param isPut Whether the option is a put or call.
     * @param expiry The expiry of the option.
     * @param strike The strike price of the option.
     * @param lastPrice The last price of the underlying asset.
     * @param amount The amount of the underlying asset.
     * @return premiumAmount The premium amount.
     */
    function _getPremiumAmount(
        bool isPut,
        uint expiry,
        uint strike,
        uint lastPrice,
        uint amount
    ) internal view returns (uint256 premiumAmount) {
        uint premiumInQuote = (amount *
            optionPricing.getOptionPrice(isPut, expiry, strike, lastPrice)) /
            (isPut ? 10 ** putAssetDecimals : 10 ** callAssetDecimals);

        if (isPut) {
            return premiumInQuote;
        }
        return (premiumInQuote * (10 ** callAssetDecimals)) / lastPrice;
    }

    /**
     * @notice Gets the price per call asset in quote asset units.
     * @param _pool The UniswapV3 pool instance.
     * @param sqrtPriceX96 The sqrt price of the pool.
     * @return price The price per call asset in quote asset units.
     */
    function _getPrice(
        IUniswapV3Pool _pool,
        uint160 sqrtPriceX96
    ) internal view returns (uint256 price) {
        if (sqrtPriceX96 <= type(uint128).max) {
            uint256 priceX192 = uint256(sqrtPriceX96) * sqrtPriceX96;
            price = callAsset == _pool.token0()
                ? FullMath.mulDiv(priceX192, 10 ** callAssetDecimals, 1 << 192)
                : FullMath.mulDiv(1 << 192, 10 ** callAssetDecimals, priceX192);
        } else {
            uint256 priceX128 = FullMath.mulDiv(
                sqrtPriceX96,
                sqrtPriceX96,
                1 << 64
            );

            price = callAsset == _pool.token0()
                ? FullMath.mulDiv(priceX128, 10 ** callAssetDecimals, 1 << 128)
                : FullMath.mulDiv(1 << 128, 10 ** callAssetDecimals, priceX128);
        }
    }

    /**
     * @notice Gets the fee for the option
     * @param amount Amount being withdrawn
     * @param premium Premium being paid for the position
     * @return fee for the option
     */
    function getFee(
        uint256 amount,
        uint256 premium
    ) public view returns (uint256) {
        return dpFee.onFeeReqReceive(address(this), amount, premium);
    }

    // admin

    /**
     * @notice Updates the addresses of the various components of the contract.
     * @param _feeTo The address of the fee recipient.
     * @param _tokeURIFetcher The address of the token URI fetcher.
     * @param _dpFee The address of the Dopex fee contract.
     * @param _optionPricing The address of the option pricing contract.
     * @param _settler The address of the settler.
     * @param _statusSettler Whether the settler is enabled.
     * @param _pool The address of the UniswapV3 pool.
     * @param _statusPools Whether the UniswapV3 pool is enabled.
     * @dev Only the owner can call this function.
     */
    function updateAddress(
        address _feeTo,
        address _tokeURIFetcher,
        address _dpFee,
        address _optionPricing,
        address _settler,
        bool _statusSettler,
        address _pool,
        bool _statusPools
    ) external onlyOwner {
        feeTo = _feeTo;
        tokenURIFetcher = _tokeURIFetcher;
        dpFee = IDopexV2ClammFeeStrategyV2(_dpFee);
        optionPricing = IOptionPricingV2(_optionPricing);
        settlers[_settler] = _statusSettler;
        approvedPools[_pool] = _statusPools;

        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        if (pool.token0() != callAsset && pool.token1() != callAsset)
            revert DopexV2OptionMarket__InvalidPool();
        if (pool.token0() != putAsset && pool.token1() != putAsset)
            revert DopexV2OptionMarket__InvalidPool();

        emit LogUpdateAddress(_tokeURIFetcher, _dpFee, _optionPricing);
    }

    // SOS admin functions
    /**
     * @notice Performs an emergency withdraw of all tokens from the contract.
     * @param token The address of the token to withdraw.
     * @dev Only the owner can call this function.
     */
    function emergencyWithdraw(address token) external onlyOwner {
        ERC20(token).transfer(
            msg.sender,
            ERC20(token).balanceOf(address(this))
        );
    }
}
