// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IThrusterPoolFactory} from "../../src/thruster-v3/v3-core/contracts/interfaces/IThrusterPoolFactory.sol";
import {IThrusterPool} from "../../src/thruster-v3/v3-core/contracts/interfaces/IThrusterPool.sol";

import {ThrusterTestLib} from "../utils/thruster-v3/ThrusterTestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManager} from "../../src/DopexV2PositionManager.sol";
import {ThrusterSingleTickLiquidityHandlerV2} from "../../src/handlers/ThrusterSingleTickLiquidityHandlerV2.sol";
import {IHandler} from "../../src/interfaces/IHandler.sol";

contract ThrusterSingleTickLiquidityHarnessV2 is Test {
    using TickMath for int24;

    ThrusterTestLib thrusterTestLib;
    DopexV2PositionManager positionManager;
    ThrusterSingleTickLiquidityHandlerV2 thrusterV3Handler;
    IHandler handler;

    constructor(
        ThrusterTestLib _thrusterTestLib,
        DopexV2PositionManager _positionManager,
        ThrusterSingleTickLiquidityHandlerV2 _thrusterV3Handler
    ) {
        thrusterTestLib = _thrusterTestLib;
        positionManager = _positionManager;
        thrusterV3Handler = _thrusterV3Handler;
        handler = IHandler(address(_thrusterV3Handler));
    }

    function getTokenId(IThrusterPool pool, address hook, int24 tickLower, int24 tickUpper)
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
        IThrusterPool pool,
        address hook,
        address user
    ) public returns (uint256 lm) {
        uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            thrusterTestLib.getCurrentSqrtPriceX96(pool),
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
                ThrusterSingleTickLiquidityHandlerV2.MintPositionParams({
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
        IThrusterPool pool,
        address hook,
        address user
    ) public returns (uint256 lb) {
        vm.startPrank(user);

        (lb) = positionManager.burnPosition(
            handler,
            abi.encode(
                ThrusterSingleTickLiquidityHandlerV2.BurnPositionParams({
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
        IThrusterPool pool,
        address hook,
        bytes calldata hookData,
        address user
    ) public returns (address[] memory tokens, uint256[] memory amounts) {
        uint128 liquidityToUse = LiquidityAmounts.getLiquidityForAmounts(
            thrusterTestLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            amount0,
            amount1
        );
        vm.startPrank(user);
        (tokens, amounts,) = positionManager.usePosition(
            handler,
            abi.encode(
                ThrusterSingleTickLiquidityHandlerV2.UsePositionParams({
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
        IThrusterPool pool,
        address hook,
        bytes calldata hookData,
        address user
    ) public {
        amountsCache = AmountCache({
            a0: amount0 + amount0ToDonate,
            a1: amount1 + amount1ToDonate,
            csp: thrusterTestLib.getCurrentSqrtPriceX96(pool),
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
                ThrusterSingleTickLiquidityHandlerV2.UnusePositionParams({
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
        IThrusterPool pool,
        address hook,
        address user
    ) public returns (uint256[] memory amounts, uint256 liquidityToDonate) {
        liquidityToDonate = LiquidityAmounts.getLiquidityForAmounts(
            thrusterTestLib.getCurrentSqrtPriceX96(pool),
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
                ThrusterSingleTickLiquidityHandlerV2.DonateParams({
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
