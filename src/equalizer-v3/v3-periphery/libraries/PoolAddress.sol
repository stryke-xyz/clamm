// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;

import "../../v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    /// @notice The identifying key of the pool
    /// @dev salt hash based on tickSpacing (constant) instead of on fees (variable)
    struct PoolKey {
        address token0;
        address token1;
        int24 tickSpacing;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param _tickSpacing The tickSpacing of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    /// @dev salt hash based on tickSpacing (constant) instead of on fees (variable)
    function getPoolKey(address tokenA, address tokenB, int24 _tickSpacing) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, tickSpacing: _tickSpacing});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    /// @dev salt hash based on tickSpacing (constant) instead of on fees (variable)
    function computeAddress(address factory, PoolKey memory key) internal view returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encode(key.token0, key.token1, key.tickSpacing)),
                            IUniswapV3Factory(factory).POOL_INIT_CODE_HASH()
                        )
                    )
                )
            )
        );
    }
}
