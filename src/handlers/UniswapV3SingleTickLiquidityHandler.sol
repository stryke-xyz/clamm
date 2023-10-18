// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IHandler} from "../interfaces/IHandler.sol";

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityManager} from "../uniswap-v3/LiquidityManager.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {FixedPoint128} from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import {ISwapRouter} from "v3-periphery/SwapRouter.sol";

contract UniswapV3SingleTickLiquidityHandler is
    ERC1155(""),
    IHandler,
    Ownable,
    Pausable,
    ReentrancyGuard,
    LiquidityManager
{
    using Math for uint128;
    using TickMath for int24;
    using SafeERC20 for IERC20;

    struct TokenIdInfo {
        uint128 totalLiquidity;
        uint128 totalSupply;
        uint128 liquidityUsed;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        uint64 lastDonation;
        uint128 donatedLiquidity;
        address token0;
        address token1;
        uint24 fee;
    }

    struct MintPositionParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    struct BurnPositionParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint128 shares;
    }

    struct UsePositionParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityToUse;
    }

    struct UnusePositionParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityToUnuse;
    }

    struct DonateParams {
        IUniswapV3Pool pool;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidityToDonate;
    }

    // events
    event LogMintedPosition(
        address user,
        uint256 tokenId,
        uint128 sharesMinted
    );
    event LogBurnedPosition(
        address user,
        uint256 tokenId,
        uint128 sharesBurned
    );
    event LogFeeCompound(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );
    event LogUsePosition(uint256 tokenId, uint128 liquidityUsed);
    event LogUnusePosition(uint256 tokenId, uint128 liquidityUnused);
    event LogDonation(uint256 tokenId, uint128 liquidityDonated);
    event LogUpdateWhitelistedApp(address _app, bool _status);
    event LogUpdatedLockedBlockDuration(uint64 _newLockedBlockDuration);

    // errors
    error UniswapV3SingleTickLiquidityHandler__NotWhitelisted();
    error UniswapV3SingleTickLiquidityHandler__InRangeLP();

    mapping(uint256 => TokenIdInfo) public tokenIds;
    mapping(address => bool) public whitelistedApps;

    ISwapRouter swapRouter;

    uint64 public constant DEFAULT_LOCKED_BLOCK_DURATION = 100;
    uint64 public lockedBlockDuration = DEFAULT_LOCKED_BLOCK_DURATION;
    uint64 public newLockedBlockDuration;

    // modifiers
    modifier onlyWhitelisted() {
        if (!whitelistedApps[msg.sender])
            revert UniswapV3SingleTickLiquidityHandler__NotWhitelisted();
        _;
    }

    constructor(
        address _factory,
        bytes32 _pool_init_code_hash,
        address _swapRouter
    ) LiquidityManager(_factory, _pool_init_code_hash) {
        swapRouter = ISwapRouter(_swapRouter);
    }

    function mintPositionHandler(
        address context,
        bytes calldata _mintPositionData
    )
        external
        onlyWhitelisted
        whenNotPaused
        nonReentrant
        returns (uint256 sharesMinted)
    {
        MintPositionParams memory _params = abi.decode(
            _mintPositionData,
            (MintPositionParams)
        );

        uint256 tokenId = uint256(
            keccak256(
                abi.encode(
                    address(this),
                    _params.pool,
                    _params.tickLower,
                    _params.tickUpper
                )
            )
        );

        TokenIdInfo storage tki = tokenIds[tokenId];

        if (tki.token0 == address(0)) {
            tki.token0 = _params.pool.token0();
            tki.token1 = _params.pool.token1();
            tki.fee = _params.pool.fee();
        }

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                _getCurrentSqrtPriceX96(_params.pool),
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(_params.liquidity)
            );

        (uint128 liquidity, , , ) = addLiquidity(
            LiquidityManager.AddLiquidityParams({
                token0: tki.token0,
                token1: tki.token1,
                fee: tki.fee,
                recipient: address(this),
                tickLower: _params.tickLower,
                tickUpper: _params.tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0,
                amount1Min: amount1
            })
        );
        if (tki.totalSupply > 0) {
            _feeCalculation(
                tki,
                _params.pool,
                _params.tickLower,
                _params.tickUpper
            );

            _compoundFees(
                tki,
                _params.pool,
                _params.tickLower,
                _params.tickUpper,
                amount0,
                amount1
            );

            uint128 shares = _convertToShares(
                liquidity,
                tokenId,
                Math.Rounding.Down
            );

            tki.totalLiquidity += liquidity;
            tki.totalSupply += shares;

            sharesMinted = shares;
        } else {
            _feeCalculation(
                tki,
                _params.pool,
                _params.tickLower,
                _params.tickUpper
            );

            tki.totalLiquidity += liquidity;
            tki.totalSupply += liquidity;

            sharesMinted = liquidity;
        }

        _mint(context, tokenId, sharesMinted, "");

        emit LogMintedPosition(context, tokenId, uint128(sharesMinted));
    }

    function burnPositionHandler(
        address context,
        bytes calldata _burnPositionData
    ) external onlyWhitelisted whenNotPaused nonReentrant returns (uint256) {
        BurnPositionParams memory _params = abi.decode(
            _burnPositionData,
            (BurnPositionParams)
        );

        uint256 tokenId = uint256(
            keccak256(
                abi.encode(
                    address(this),
                    _params.pool,
                    _params.tickLower,
                    _params.tickUpper
                )
            )
        );

        TokenIdInfo storage tki = tokenIds[tokenId];

        uint128 liquidityToBurn = _convertToAssets(
            _params.shares,
            tokenId,
            Math.Rounding.Up
        );

        (uint256 amount0, uint256 amount1) = _params.pool.burn(
            _params.tickLower,
            _params.tickUpper,
            liquidityToBurn
        );

        _feeCalculation(
            tki,
            _params.pool,
            _params.tickLower,
            _params.tickUpper
        );

        uint128 feesOwedToken0;
        uint128 feesOwedToken1;

        {
            uint256 a00 = LiquidityAmounts.getAmount0ForLiquidity(
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(liquidityToBurn)
            );

            uint256 a11 = LiquidityAmounts.getAmount1ForLiquidity(
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(liquidityToBurn)
            );

            uint256 a0 = LiquidityAmounts.getAmount0ForLiquidity(
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(tki.totalLiquidity)
            );

            uint256 a1 = LiquidityAmounts.getAmount1ForLiquidity(
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(tki.totalLiquidity)
            );

            feesOwedToken0 = uint128((tki.tokensOwed0 * a00) / a0);
            feesOwedToken1 = uint128((tki.tokensOwed1 * a11) / a1);
        }

        tki.tokensOwed0 -= feesOwedToken0;
        tki.tokensOwed1 -= feesOwedToken1;

        _params.pool.collect(
            context,
            _params.tickLower,
            _params.tickUpper,
            uint128(amount0 + feesOwedToken0),
            uint128(amount1 + feesOwedToken1)
        );

        tki.totalLiquidity -= liquidityToBurn;
        tki.totalSupply -= _params.shares;

        _burn(context, tokenId, _params.shares);

        emit LogBurnedPosition(context, tokenId, _params.shares);
        return (_params.shares);
    }

    function usePositionHandler(
        bytes calldata _usePositionHandler
    )
        external
        onlyWhitelisted
        whenNotPaused
        nonReentrant
        returns (address[] memory, uint256[] memory, uint256)
    {
        UsePositionParams memory _params = abi.decode(
            _usePositionHandler,
            (UsePositionParams)
        );
        uint256 tokenId = uint256(
            keccak256(
                abi.encode(
                    address(this),
                    _params.pool,
                    _params.tickLower,
                    _params.tickUpper
                )
            )
        );

        TokenIdInfo storage tki = tokenIds[tokenId];

        (uint256 amount0, uint256 amount1) = _params.pool.burn(
            _params.tickLower,
            _params.tickUpper,
            uint128(_params.liquidityToUse)
        );

        _params.pool.collect(
            msg.sender,
            _params.tickLower,
            _params.tickUpper,
            uint128(amount0),
            uint128(amount1)
        );

        _feeCalculation(
            tki,
            _params.pool,
            _params.tickLower,
            _params.tickUpper
        );

        tki.liquidityUsed += _params.liquidityToUse;

        address[] memory tokens = new address[](2);
        tokens[0] = tki.token0;
        tokens[1] = tki.token1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        emit LogUsePosition(tokenId, _params.liquidityToUse);
        return (tokens, amounts, _params.liquidityToUse);
    }

    function unusePositionHandler(
        bytes calldata _unusePositionData
    )
        external
        onlyWhitelisted
        whenNotPaused
        nonReentrant
        returns (uint256[] memory, uint256)
    {
        UnusePositionParams memory _params = abi.decode(
            _unusePositionData,
            (UnusePositionParams)
        );

        uint256 tokenId = uint256(
            keccak256(
                abi.encode(
                    address(this),
                    _params.pool,
                    _params.tickLower,
                    _params.tickUpper
                )
            )
        );

        TokenIdInfo storage tki = tokenIds[tokenId];

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                _getCurrentSqrtPriceX96(_params.pool),
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(_params.liquidityToUnuse)
            );

        (uint128 liquidity, , , ) = addLiquidity(
            LiquidityManager.AddLiquidityParams({
                token0: tki.token0,
                token1: tki.token1,
                fee: tki.fee,
                recipient: address(this),
                tickLower: _params.tickLower,
                tickUpper: _params.tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0,
                amount1Min: amount1
            })
        );

        _feeCalculation(
            tki,
            _params.pool,
            _params.tickLower,
            _params.tickUpper
        );

        if (tki.liquidityUsed >= liquidity) {
            tki.liquidityUsed -= liquidity;
        } else {
            tki.totalLiquidity += (liquidity - tki.liquidityUsed);
            tki.liquidityUsed = 0;
        }

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        emit LogUnusePosition(tokenId, liquidity);
        return (amounts, uint256(liquidity));
    }

    function donateToPosition(
        bytes calldata _donateData
    )
        external
        onlyWhitelisted
        whenNotPaused
        nonReentrant
        returns (uint256[] memory, uint256)
    {
        DonateParams memory _params = abi.decode(_donateData, (DonateParams));

        uint256 tokenId = uint256(
            keccak256(
                abi.encode(
                    address(this),
                    _params.pool,
                    _params.tickLower,
                    _params.tickUpper
                )
            )
        );

        TokenIdInfo storage tki = tokenIds[tokenId];

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                _getCurrentSqrtPriceX96(_params.pool),
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(_params.liquidityToDonate)
            );

        (uint128 liquidity, , , ) = addLiquidity(
            LiquidityManager.AddLiquidityParams({
                token0: tki.token0,
                token1: tki.token1,
                fee: tki.fee,
                recipient: address(this),
                tickLower: _params.tickLower,
                tickUpper: _params.tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: amount0,
                amount1Min: amount1
            })
        );

        _feeCalculation(
            tki,
            _params.pool,
            _params.tickLower,
            _params.tickUpper
        );

        tki.totalLiquidity += liquidity;

        // can it overflow?
        tki.donatedLiquidity = _donationLocked(tokenId) + liquidity;

        tki.lastDonation = uint64(block.number);

        if (newLockedBlockDuration != 0) {
            lockedBlockDuration = newLockedBlockDuration;
            newLockedBlockDuration = 0;
        }

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        emit LogDonation(tokenId, liquidity);
        return (amounts, liquidity);
    }

    function _feeCalculation(
        TokenIdInfo storage _tki,
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) internal {
        bytes32 positionKey = _computePositionKey(
            address(this),
            _tickLower,
            _tickUpper
        );
        (
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,

        ) = _pool.positions(positionKey);
        unchecked {
            _tki.tokensOwed0 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside0LastX128 - _tki.feeGrowthInside0LastX128,
                    _tki.totalLiquidity - _tki.liquidityUsed,
                    FixedPoint128.Q128
                )
            );
            _tki.tokensOwed1 += uint128(
                FullMath.mulDiv(
                    feeGrowthInside1LastX128 - _tki.feeGrowthInside1LastX128,
                    _tki.totalLiquidity - _tki.liquidityUsed,
                    FixedPoint128.Q128
                )
            );

            _tki.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
            _tki.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        }
    }

    function _compoundFees(
        TokenIdInfo storage tki,
        IUniswapV3Pool _pool,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal {
        if (amount0 > 0 && amount1 > 0)
            revert UniswapV3SingleTickLiquidityHandler__InRangeLP();

        if (tki.tokensOwed0 > 0 || tki.tokensOwed1 > 0) {
            (uint256 a0, uint256 a1) = _pool.collect(
                address(this),
                _tickLower,
                _tickUpper,
                uint128(tki.tokensOwed0),
                uint128(tki.tokensOwed1)
            );

            (tki.tokensOwed0, tki.tokensOwed1) = (0, 0);

            bool isAmount0 = amount0 > 0;

            IERC20(isAmount0 ? tki.token1 : tki.token0).safeApprove(
                address(swapRouter),
                isAmount0 ? a1 : a0
            );

            uint256 amountOut = swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: isAmount0 ? tki.token1 : tki.token0,
                    tokenOut: isAmount0 ? tki.token0 : tki.token1,
                    fee: tki.fee,
                    recipient: address(this),
                    deadline: block.timestamp + 5 days,
                    amountIn: isAmount0 ? a1 : a0,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );

            (uint128 liquidity, , , ) = UniswapV3SingleTickLiquidityHandler(
                address(this)
            ).addLiquidity(
                    LiquidityManager.AddLiquidityParams({
                        token0: tki.token0,
                        token1: tki.token1,
                        fee: tki.fee,
                        recipient: address(this),
                        tickLower: _tickLower,
                        tickUpper: _tickUpper,
                        amount0Desired: a0 + (isAmount0 ? amountOut : 0),
                        amount1Desired: a1 + (isAmount0 ? 0 : amountOut),
                        amount0Min: a0 + (isAmount0 ? amountOut : 0),
                        amount1Min: a1 + (isAmount0 ? 0 : amountOut)
                    })
                );
            tki.totalLiquidity += liquidity;

            emit LogFeeCompound(_pool, _tickLower, _tickUpper, liquidity);
        }
    }

    function getHandlerIdentifier(
        bytes calldata _data
    ) external view returns (uint256 handlerIdentifierId) {
        (IUniswapV3Pool pool, int24 tickLower, int24 tickUpper) = abi.decode(
            _data,
            (IUniswapV3Pool, int24, int24)
        );

        return
            uint256(
                keccak256(abi.encode(address(this), pool, tickLower, tickUpper))
            );
    }

    function tokensToPullForMint(
        bytes calldata _mintPositionData
    ) external view returns (address[] memory, uint256[] memory) {
        MintPositionParams memory _params = abi.decode(
            _mintPositionData,
            (MintPositionParams)
        );

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                _getCurrentSqrtPriceX96(_params.pool),
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(_params.liquidity)
            );

        address[] memory tokens = new address[](2);
        tokens[0] = _params.pool.token0();
        tokens[1] = _params.pool.token1();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        return (tokens, amounts);
    }

    function tokensToPullForUnUse(
        bytes calldata _unusePositionData
    ) external view returns (address[] memory, uint256[] memory) {
        UnusePositionParams memory _params = abi.decode(
            _unusePositionData,
            (UnusePositionParams)
        );

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                _getCurrentSqrtPriceX96(_params.pool),
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(_params.liquidityToUnuse)
            );

        address[] memory tokens = new address[](2);
        tokens[0] = _params.pool.token0();
        tokens[1] = _params.pool.token1();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        return (tokens, amounts);
    }

    function tokensToPullForDonate(
        bytes calldata _donatePosition
    ) external view returns (address[] memory, uint256[] memory) {
        DonateParams memory _params = abi.decode(
            _donatePosition,
            (DonateParams)
        );

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                _getCurrentSqrtPriceX96(_params.pool),
                _params.tickLower.getSqrtRatioAtTick(),
                _params.tickUpper.getSqrtRatioAtTick(),
                uint128(_params.liquidityToDonate)
            );

        address[] memory tokens = new address[](2);
        tokens[0] = _params.pool.token0();
        tokens[1] = _params.pool.token1();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        return (tokens, amounts);
    }

    function _donationLocked(uint256 tokenId) internal view returns (uint128) {
        TokenIdInfo memory tki = tokenIds[tokenId];

        if (block.number >= tki.lastDonation + lockedBlockDuration) return 0;

        uint128 donationLocked = tki.donatedLiquidity -
            (tki.donatedLiquidity * (uint64(block.number) - tki.lastDonation)) /
            lockedBlockDuration;

        return donationLocked;
    }

    function _convertToShares(
        uint128 assets,
        uint256 tokenId,
        Math.Rounding rounding
    ) internal view returns (uint128) {
        return
            uint128(
                assets.mulDiv(
                    tokenIds[tokenId].totalSupply,
                    (tokenIds[tokenId].totalLiquidity + 1) -
                        _donationLocked(tokenId),
                    rounding
                )
            );
    }

    function _convertToAssets(
        uint128 shares,
        uint256 tokenId,
        Math.Rounding rounding
    ) internal view returns (uint128) {
        return
            uint128(
                shares.mulDiv(
                    (tokenIds[tokenId].totalLiquidity + 1) -
                        _donationLocked(tokenId),
                    tokenIds[tokenId].totalSupply,
                    rounding
                )
            );
    }

    function _getCurrentSqrtPriceX96(
        IUniswapV3Pool pool
    ) internal view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96, , , , , , ) = pool.slot0();
    }

    function _computePositionKey(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }

    // admin functions
    function updateWhitelistedApps(
        address _app,
        bool _status
    ) external onlyOwner {
        whitelistedApps[_app] = _status;
        emit LogUpdateWhitelistedApp(_app, _status);
    }

    function updateLockedBlockDuration(
        uint64 _newLockedBlockDuration
    ) external onlyOwner {
        newLockedBlockDuration = _newLockedBlockDuration;
        emit LogUpdatedLockedBlockDuration(_newLockedBlockDuration);
    }

    // SOS admin functions
    function forceWithdrawUniswapV3Liquidity(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external onlyOwner {
        pool.burn(tickLower, tickUpper, liquidity);
        (, , , uint128 t0, uint128 t1) = pool.positions(
            _computePositionKey(address(this), tickLower, tickUpper)
        );
        pool.collect(msg.sender, tickLower, tickUpper, t0, t1);
    }

    function emergencyWithdraw(address token) external onlyOwner {
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    function emergencyPause() external onlyOwner {
        _pause();
    }

    function emergencyUnpause() external onlyOwner {
        _unpause();
    }
}
