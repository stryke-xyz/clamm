// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IBulletXV3Factory} from "../../src/bulletX-v3/v3-core/contracts/interfaces/IBulletXV3Factory.sol";
import {IBulletXV3Pool} from "../../src/bulletX-v3/v3-core/contracts/interfaces/IBulletXV3Pool.sol";

import {BulletXV3TestLib} from "../utils/bulletX-v3/BulletXV3TestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {BulletXV3SingleTickLiquidityHandlerV2} from "../../src/handlers/BulletXV3SingleTickLiquidityHandlerV2.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";

contract BulletXV3SingleTickLiquidityHarnessV2 is Test {
    using TickMath for int24;

    BulletXV3TestLib bulletXV3TestLib;
    DopexV2PositionManager positionManager;
    BulletXV3SingleTickLiquidityHandlerV2 bulletXV3Handler;
    IHandler handler;

    constructor(
        BulletXV3TestLib _bulletXV3TestLib,
        DopexV2PositionManager _positionManager,
        BulletXV3SingleTickLiquidityHandlerV2 _bulletXV3Handler
    ) {
        bulletXV3TestLib = _bulletXV3TestLib;
        positionManager = _positionManager;
        bulletXV3Handler = _bulletXV3Handler;
        handler = IHandler(address(_bulletXV3Handler));
    }

    function getTokenId(IBulletXV3Pool pool, address hook, int24 tickLower, int24 tickUpper)
        public
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(address(handler), pool, hook, tickLower, tickUpper)));
    }

    function mintPosition(
        ERC20Mock token0,
        ERC20Mock token1,
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        IBulletXV3Pool pool,
        address hook,
        address user
    ) public returns (uint256 lm) {
        uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            bulletXV3TestLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            amount0,
            amount1
        );

        token0.mint(user, amount0);
        token1.mint(user, amount1);

        vm.startPrank(user);
        token0.increaseAllowance(address(positionManager), amount0);
        token1.increaseAllowance(address(positionManager), amount1);

        (lm) = positionManager.mintPosition(
            handler,
            abi.encode(
                BulletXV3SingleTickLiquidityHandlerV2.MintPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidity: liquidityToMint
                })
            )
        );
        vm.stopPrank();
    }

    function burnPosition(
        uint256 shares,
        int24 tickLower,
        int24 tickUpper,
        IBulletXV3Pool pool,
        address hook,
        address user
    ) public returns (uint256 lb) {
        vm.startPrank(user);

        (lb) = positionManager.burnPosition(
            handler,
            abi.encode(
                BulletXV3SingleTickLiquidityHandlerV2.BurnPositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    shares: uint128(shares)
                })
            )
        );

        vm.stopPrank();
    }

    function usePosition(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper,
        IBulletXV3Pool pool,
        address hook,
        bytes calldata hookData,
        address user
    ) public returns (address[] memory tokens, uint256[] memory amounts) {
        uint128 liquidityToUse = LiquidityAmounts.getLiquidityForAmounts(
            bulletXV3TestLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            amount0,
            amount1
        );
        vm.startPrank(user);
        (tokens, amounts,) = positionManager.usePosition(
            handler,
            abi.encode(
                BulletXV3SingleTickLiquidityHandlerV2.UsePositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityToUse: liquidityToUse
                }),
                hookData
            )
        );
        vm.stopPrank();
    }

    struct AmountCache {
        uint256 a0;
        uint256 a1;
        uint160 csp;
        uint160 tl;
        uint160 tu;
    }

    AmountCache amountsCache;

    function _getLiq() internal view returns (uint128) {
        return uint128(
            LiquidityAmounts.getLiquidityForAmounts(
                amountsCache.csp, amountsCache.tl, amountsCache.tu, amountsCache.a0, amountsCache.a1
            )
        );
    }

    function unusePosition(
        uint256 amount0,
        uint256 amount1,
        uint256 amount0ToDonate,
        uint256 amount1ToDonate,
        int24 tickLower,
        int24 tickUpper,
        IBulletXV3Pool pool,
        address hook,
        bytes calldata hookData,
        address user
    ) public {
        // uint256 liquidityToUnuse;
        // {
        //     liquidityToUnuse = LiquidityAmounts.getLiquidityForAmounts(
        //         bulletXV3TestLib.getCurrentSqrtPriceX96(pool),
        //         tickLower.getSqrtRatioAtTick(),
        //         tickUpper.getSqrtRatioAtTick(),
        //         amount0 + amount0ToDonate,
        //         amount1 + amount1ToDonate
        //     );
        // }

        amountsCache = AmountCache({
            a0: amount0 + amount0ToDonate,
            a1: amount1 + amount1ToDonate,
            csp: bulletXV3TestLib.getCurrentSqrtPriceX96(pool),
            tl: tickLower.getSqrtRatioAtTick(),
            tu: tickUpper.getSqrtRatioAtTick()
        });

        vm.startPrank(user);
        {
            if (amount0ToDonate > 0) {
                ERC20Mock(pool.token0()).mint(user, amount0ToDonate);
            }
            if (amount1ToDonate > 0) {
                ERC20Mock(pool.token1()).mint(user, amount1ToDonate);
            }

            ERC20Mock(pool.token0()).increaseAllowance(address(positionManager), amount0 + amount0ToDonate);
            ERC20Mock(pool.token1()).increaseAllowance(address(positionManager), amount1 + amount1ToDonate);
        }

        positionManager.unusePosition(
            handler,
            abi.encode(
                BulletXV3SingleTickLiquidityHandlerV2.UnusePositionParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityToUnuse: _getLiq()
                }),
                hookData
            )
        );
        vm.stopPrank();
    }

    function donatePosition(
        ERC20Mock token0,
        ERC20Mock token1,
        uint256 amount0,
        uint256 amount1,
        uint256 amount0ToDonate,
        uint256 amount1ToDonate,
        int24 tickLower,
        int24 tickUpper,
        IBulletXV3Pool pool,
        address hook,
        address user
    ) public returns (uint256[] memory amounts, uint256 liquidityToDonate) {
        liquidityToDonate = LiquidityAmounts.getLiquidityForAmounts(
            bulletXV3TestLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            amount0 + amount0ToDonate,
            amount1 + amount1ToDonate
        );

        vm.startPrank(user);
        if (amount0ToDonate > 0) token0.mint(user, amount0ToDonate);
        if (amount1ToDonate > 0) token1.mint(user, amount1ToDonate);

        token0.increaseAllowance(address(positionManager), amount0 + amount0ToDonate);
        token1.increaseAllowance(address(positionManager), amount1 + amount1ToDonate);

        (amounts,) = positionManager.donateToPosition(
            handler,
            abi.encode(
                BulletXV3SingleTickLiquidityHandlerV2.DonateParams({
                    pool: pool,
                    hook: hook,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityToDonate: uint128(liquidityToDonate)
                })
            )
        );
        vm.stopPrank();
    }
}
