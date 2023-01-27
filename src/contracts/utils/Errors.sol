// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * A collection of generic errors that can be referenced across multiple
 * contracts. Contract-specific errors should still be stored in their
 * individual Solidity files.
 */

/// ..
error CannotSetNullAddress();

/// ..
error InsufficientAmount();

/// ..
error PercentageTooHigh(uint amount);

/// ..
error TransferFailed();

/// require(amount != 0, 'Cannot deposit 0');
/// ..
error CannotDepositZeroAmount();

/// require(amount != 0, 'Cannot claim 0');
/// ..
error CannotWithdrawZeroAmount();

/// require(success, 'Unable to claim rewards');
/// ..
error NoRewardsAvailableToClaim();

/// If the requested strategy is not approved
error StrategyNotApproved(address strategy);

// If the requested collection is not approved
error CollectionNotApproved(address collection);
