// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IBulletXV3PoolActions#mint
/// @notice Any contract that calls IBulletXV3PoolActions#mint must implement this interface
interface IBulletXV3MintCallback {
    /// @notice Called to `msg.sender` after minting liquidity to a position from IBulletXV3Pool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a BulletXV3Pool deployed by the canonical BulletXV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IBulletXV3PoolActions#mint call
    function bulletXV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external;
}
