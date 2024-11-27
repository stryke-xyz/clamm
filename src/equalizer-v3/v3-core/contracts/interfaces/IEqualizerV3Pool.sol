// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './pool/IEqualizerV3PoolImmutables.sol';
import './pool/IEqualizerV3PoolState.sol';
import './pool/IEqualizerV3PoolDerivedState.sol';
import './pool/IEqualizerV3PoolActions.sol';
import './pool/IEqualizerV3PoolOwnerActions.sol';
import './pool/IEqualizerV3PoolEvents.sol';

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IEqualizerV3Pool is
    IEqualizerV3PoolImmutables,
    IEqualizerV3PoolState,
    IEqualizerV3PoolDerivedState,
    IEqualizerV3PoolActions,
    IEqualizerV3PoolOwnerActions,
    IEqualizerV3PoolEvents
{

}