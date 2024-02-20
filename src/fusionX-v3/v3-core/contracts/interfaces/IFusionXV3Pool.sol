// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./pool/IFusionXV3PoolImmutables.sol";
import "./pool/IFusionXV3PoolState.sol";
import "./pool/IFusionXV3PoolDerivedState.sol";
import "./pool/IFusionXV3PoolActions.sol";
import "./pool/IFusionXV3PoolOwnerActions.sol";
import "./pool/IFusionXV3PoolEvents.sol";

/// @title The interface for a FusionXSwap V3 Pool
/// @notice A FusionXSwap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IFusionXV3Pool is
    IFusionXV3PoolImmutables,
    IFusionXV3PoolState,
    IFusionXV3PoolDerivedState,
    IFusionXV3PoolActions,
    IFusionXV3PoolOwnerActions,
    IFusionXV3PoolEvents
{}
