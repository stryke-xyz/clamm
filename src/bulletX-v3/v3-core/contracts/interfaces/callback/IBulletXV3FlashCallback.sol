// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Callback for IBulletXV3PoolActions#flash
/// @notice Any contract that calls IBulletXV3PoolActions#flash must implement this interface
interface IBulletXV3FlashCallback {
    /// @notice Called to `msg.sender` after transferring to the recipient from IBulletXV3Pool#flash.
    /// @dev In the implementation you must repay the pool the tokens sent by flash plus the computed fee amounts.
    /// The caller of this method must be checked to be a BulletXV3Pool deployed by the canonical BulletXV3Factory.
    /// @param fee0 The fee amount in token0 due to the pool by the end of the flash
    /// @param fee1 The fee amount in token1 due to the pool by the end of the flash
    /// @param data Any data passed through by the caller via the IBulletXV3PoolActions#flash call
    function bulletXV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}
