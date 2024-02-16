// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./pool/IButterPoolImmutables.sol";
import "./pool/IButterPoolState.sol";
import "./pool/IButterPoolDerivedState.sol";
import "./pool/IButterPoolActions.sol";
import "./pool/IButterPoolOwnerActions.sol";
import "./pool/IButterPoolEvents.sol";

/// @title The interface for an Butter Pool
/// @notice A pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IButterPool is
    IButterPoolImmutables,
    IButterPoolState,
    IButterPoolDerivedState,
    IButterPoolActions,
    IButterPoolOwnerActions,
    IButterPoolEvents
{}
