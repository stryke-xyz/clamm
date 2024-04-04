// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Interfaces
import {IButterFactory} from "./v3-core/contracts/interfaces/IButterFactory.sol";
import {IButterMintCallback} from "./v3-core/contracts/interfaces/callback/IButterMintCallback.sol";
import {IButterPool} from "./v3-core/contracts/interfaces/IButterPool.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

// Libraries
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Pancake V3
abstract contract LiquidityManager is IButterMintCallback {
    address public immutable factory;
    bytes32 public immutable POOL_INIT_CODE_HASH;
    // bytes32 internal constant POOL_INIT_CODE_HASH =
    //     0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff;

    // bytes32 internal constant POOL_INIT_CODE_HASH =
    //     0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    constructor(address _factory, bytes32 _pool_init_code_hash) {
        factory = _factory;
        POOL_INIT_CODE_HASH = _pool_init_code_hash;
    }

    struct MintCallbackData {
        PoolKey poolKey;
        address payer;
    }

    /// @inheritdoc IButterMintCallback
    function butterMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        verifyCallback(factory, decoded.poolKey);

        if (amount0Owed > 0) {
            pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
        }
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        uint24 fee;
        address recipient;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    /// @notice Add liquidity to an initialized pool
    function addLiquidity(AddLiquidityParams memory params)
        public
        returns (uint128 liquidity, uint256 amount0, uint256 amount1, IButterPool pool)
    {
        PoolKey memory poolKey = PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});

        pool = IButterPool(computeAddress(factory, poolKey));

        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, params.amount0Desired, params.amount1Desired
            );
        }

        (amount0, amount1) = pool.mint(
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(address token, address payer, address recipient, uint256 value) internal {
        // pull payment
        if (payer == address(this)) {
            SafeERC20.safeTransfer(IERC20(token), recipient, value);
        } else {
            SafeERC20.safeTransferFrom(IERC20(token), payer, recipient, value);
        }
    }

    function getPoolKey(address tokenA, address tokenB, uint24 fee) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    function computeAddress(address _factory, PoolKey memory key) internal view returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            _factory,
                            keccak256(abi.encode(key.token0, key.token1, key.fee)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    function verifyCallback(address _factory, address tokenA, address tokenB, uint24 fee)
        internal
        view
        returns (IButterPool pool)
    {
        return verifyCallback(_factory, getPoolKey(tokenA, tokenB, fee));
    }

    function verifyCallback(address _factory, PoolKey memory poolKey) internal view returns (IButterPool pool) {
        pool = IButterPool(computeAddress(_factory, poolKey));
        require(msg.sender == address(pool));
    }
}
