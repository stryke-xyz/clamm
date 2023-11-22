// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {IDopexV2PositionManager} from "../src/interfaces/IDopexV2PositionManager.sol";
import {DopexV2PositionManager} from "../src/DopexV2PositionManager.sol";
import {IHandler} from "../src/interfaces/IHandler.sol";
import {UniswapV3SingleTickLiquidityHandler} from "../src/handlers/UniswapV3SingleTickLiquidityHandler.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

contract MultiDepositScript is Script {
    using TickMath for int24;

    struct LoopCache {
        int24 tickLower;
        int24 tickUpper;
        uint256 amount;
        uint128 liquidityToDeposit;
    }

    function run() public {
        IDopexV2PositionManager pm = IDopexV2PositionManager(
            0xE4bA6740aF4c666325D49B3112E4758371386aDc
        );

        UniswapV3SingleTickLiquidityHandler handler = UniswapV3SingleTickLiquidityHandler(
                0xe11d346757d052214686bCbC860C94363AfB4a9A
            );

        IUniswapV3Pool pool = IUniswapV3Pool(
            0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443
        ); // WETH/USDC 0.05%

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        int24 tickLower = -199930;
        int24 tickUpper = -199920;

        uint256 totalAmountToDeposit = 1e17;

        uint256 tickInterval = 1;

        uint256 tickSpacing = 10;

        uint256 totalStrikes = 4;

        bytes[] memory multiCallData = new bytes[](totalStrikes);

        {
            LoopCache memory lc = LoopCache({
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount: totalAmountToDeposit / totalStrikes,
                liquidityToDeposit: 0
            });

            for (uint i; i < totalStrikes; i++) {
                // make sure to change the token0 and token1 amount
                lc.liquidityToDeposit = LiquidityAmounts.getLiquidityForAmounts(
                    sqrtPriceX96,
                    lc.tickLower.getSqrtRatioAtTick(),
                    lc.tickUpper.getSqrtRatioAtTick(),
                    lc.amount,
                    0
                );

                console.log("--------------------");
                console.logInt(lc.tickLower);
                console.logInt(lc.tickUpper);
                console.log("Amount", lc.amount);
                console.log("Liquidity", lc.liquidityToDeposit);
                console.log("--------------------");

                multiCallData[i] = abi.encodeWithSelector(
                    DopexV2PositionManager.mintPosition.selector,
                    (address(handler)),
                    abi.encode(
                        UniswapV3SingleTickLiquidityHandler.MintPositionParams({
                            pool: pool,
                            tickLower: lc.tickLower,
                            tickUpper: lc.tickUpper,
                            liquidity: lc.liquidityToDeposit
                        })
                    )
                );

                // pm.mintPosition(
                //     IHandler(address(handler)),
                //     abi.encode(
                //         UniswapV3SingleTickLiquidityHandler.MintPositionParams({
                //             pool: pool,
                //             tickLower: lc.tickLower,
                //             tickUpper: lc.tickUpper,
                //             liquidity: lc.liquidityToDeposit
                //         })
                //     )
                // );

                lc.tickLower = lc.tickLower > 0
                    ? lc.tickLower + int24(uint24(tickInterval * tickSpacing))
                    : lc.tickLower - int24(uint24(tickInterval * tickSpacing));

                lc.tickUpper = lc.tickUpper > 0
                    ? lc.tickUpper + int24(uint24(tickInterval * tickSpacing))
                    : lc.tickUpper - int24(uint24(tickInterval * tickSpacing));
            }
        }
        vm.startBroadcast();

        // make sure to approve relevant token0 or token1
        ERC20(pool.token0()).approve(address(pm), totalAmountToDeposit);
        // ERC20(pool.token1()).approve(address(pm), totalAmountToDeposit);

        DopexV2PositionManager(address(pm)).multicall(multiCallData);

        vm.stopBroadcast();
    }
}
