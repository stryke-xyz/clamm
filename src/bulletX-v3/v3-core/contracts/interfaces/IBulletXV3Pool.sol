// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./pool/IBulletXV3PoolImmutables.sol";
import "./pool/IBulletXV3PoolState.sol";
import "./pool/IBulletXV3PoolDerivedState.sol";
import "./pool/IBulletXV3PoolActions.sol";
import "./pool/IBulletXV3PoolOwnerActions.sol";
import "./pool/IBulletXV3PoolEvents.sol";

/// @title The interface for a BulletXSwap V3 Pool
/// @notice A BulletXSwap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IBulletXV3Pool is
    IBulletXV3PoolImmutables,
    IBulletXV3PoolState,
    IBulletXV3PoolDerivedState,
    IBulletXV3PoolActions,
    IBulletXV3PoolOwnerActions,
    IBulletXV3PoolEvents
{}
