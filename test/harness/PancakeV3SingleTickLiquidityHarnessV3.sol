// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IPancakeV3Factory} from "../../src/pancake-v3/v3-core/contracts/interfaces/IPancakeV3Factory.sol";
import {IPancakeV3Pool} from "../../src/pancake-v3/v3-core/contracts/interfaces/IPancakeV3Pool.sol";

import {PancakeV3TestLib} from "../utils/pancake-v3/PancakeV3TestLib.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";

import {DopexV2PositionManagerV2} from "../../src/DopexV2PositionManagerV2.sol";
import {PancakeV3SingleTickLiquidityHandlerV3} from "../../src/handlers/PancakeV3SingleTickLiquidityHandlerV3.sol";
import {IHandlerV3} from "../../src/interfaces/IHandlerV3.sol";

contract PancakeV3SingleTickLiquidityHarnessV3 is Test {
    using TickMath for int24;

    PancakeV3TestLib pancakeV3TestLib;
    DopexV2PositionManagerV2 positionManager;
    PancakeV3SingleTickLiquidityHandlerV3 pcsV3Handler;
    IHandlerV3 handler;

    constructor(
        PancakeV3TestLib _pancakeV3TestLib,
        DopexV2PositionManagerV2 _positionManager,
        PancakeV3SingleTickLiquidityHandlerV3 _pcsV3Handler
    ) {
        pancakeV3TestLib = _pancakeV3TestLib;
        positionManager = _positionManager;
        pcsV3Handler = _pcsV3Handler;
        handler = IHandlerV3(address(_pcsV3Handler));
    }

    function getTokenId(IPancakeV3Pool pool, address hook, int24 tickLower, int24 tickUpper)
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
        IPancakeV3Pool pool,
        address hook,
        address user
    ) public returns (uint256 lm) {
        uint128 liquidityToMint = LiquidityAmounts.getLiquidityForAmounts(
            pancakeV3TestLib.getCurrentSqrtPriceX96(pool),
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
                PancakeV3SingleTickLiquidityHandlerV3.MintPositionParams({
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
        IPancakeV3Pool pool,
        address hook,
        address user
    ) public returns (uint256 lb) {
        vm.startPrank(user);

        (lb) = positionManager.burnPosition(
            handler,
            abi.encode(
                PancakeV3SingleTickLiquidityHandlerV3.BurnPositionParams({
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
        IPancakeV3Pool pool,
        address hook,
        bytes calldata hookData,
        address user
    ) public returns (address[] memory tokens, uint256[] memory amounts) {
        uint128 liquidityToUse = LiquidityAmounts.getLiquidityForAmounts(
            pancakeV3TestLib.getCurrentSqrtPriceX96(pool),
            tickLower.getSqrtRatioAtTick(),
            tickUpper.getSqrtRatioAtTick(),
            amount0,
            amount1
        );
        vm.startPrank(user);
        (tokens, amounts,) = positionManager.usePosition(
            handler,
            abi.encode(
                PancakeV3SingleTickLiquidityHandlerV3.UsePositionParams({
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
        IPancakeV3Pool pool,
        address hook,
        bytes calldata hookData,
        address user
    ) public {
        amountsCache = AmountCache({
            a0: amount0 + amount0ToDonate,
            a1: amount1 + amount1ToDonate,
            csp: pancakeV3TestLib.getCurrentSqrtPriceX96(pool),
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
                PancakeV3SingleTickLiquidityHandlerV3.UnusePositionParams({
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
        IPancakeV3Pool pool,
        address hook,
        address user
    ) public returns (uint256[] memory amounts, uint256 liquidityToDonate) {
        liquidityToDonate = LiquidityAmounts.getLiquidityForAmounts(
            pancakeV3TestLib.getCurrentSqrtPriceX96(pool),
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
                PancakeV3SingleTickLiquidityHandlerV3.DonateParams({
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
