// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * A collection of generic errors that can be referenced across multiple
 * contracts. Contract-specific errors should still be stored in their
 * individual Solidity files.
 */

/// If a NULL address tries to be stored which should not be accepted
error CannotSetNullAddress();

/// If the caller has entered an insufficient amount to process the action. This
/// will likely be a zero amount.
error InsufficientAmount();

/// If the caller enters a percentage value that is too high for the requirements
error PercentageTooHigh(uint amount);

/// If a required ETH or token `transfer` call fails
error TransferFailed();

/// If a user calls a deposit related function with a zero amount
error CannotDepositZeroAmount();

/// If a user calls a withdrawal related function with a zero amount
error CannotWithdrawZeroAmount();

/// If there are no rewards available to be claimed
error NoRewardsAvailableToClaim();

/// If the requested collection is not approved
/// @param collection Address of the collection requested
error CollectionNotApproved(address collection);

/// If the requested strategy implementation is not approved
/// @param strategyImplementation Address of the strategy implementation requested
error StrategyNotApproved(address strategyImplementation);
