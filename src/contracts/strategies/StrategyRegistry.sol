// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AuthorityControl} from '../authorities/AuthorityControl.sol';

import {IStrategyRegistry} from '../../interfaces/strategies/StrategyRegistry.sol';

/// If a zero address strategy tries to be approved
error CannotApproveNullStrategy();

/// If a strategy that is not already approved attempts to be revoked
/// @param contractAddr Address of the contract trying to be revoked
error CannotRevokeUnapprovedStrategy(address contractAddr);

/**
 * Allows strategy contracts to be approved and revoked by addresses holding the
 * {StrategyManager} role. Only once approved can these strategies be applied to
 * new or existing vaults.
 *
 * These strategies will be heavily defined in the {IStrategy} interface, but this
 * Factory focusses solely on managing the list of available vault strategies.
 */
contract StrategyRegistry is AuthorityControl, IStrategyRegistry {
    /// Store a mapping of our approved strategies
    mapping(address => bool) internal strategies;

    /**
     * Set up our {AuthorityControl}.
     */
    constructor(address _authority) AuthorityControl(_authority) {}

    /**
     * Returns `true` if the contract address is an approved strategy, otherwise
     * returns `false`.
     *
     * @param contractAddr Address of the contract to check
     *
     * @return If the contract has been approved
     */
    function isApproved(address contractAddr) external view returns (bool) {
        return strategies[contractAddr];
    }

    /**
     * Approves a strategy contract to be used for vaults. The strategy must hold a defined
     * implementation and conform to the {IStrategy} interface.
     *
     * If the strategy is already approved, then no action will be taken.
     *
     * @param contractAddr Strategy to be approved
     */
    function approveStrategy(address contractAddr) external onlyRole(STRATEGY_MANAGER) {
        if (contractAddr == address(0)) {
            revert CannotApproveNullStrategy();
        }

        if (!strategies[contractAddr]) {
            strategies[contractAddr] = true;
            emit StrategyApproved(contractAddr);
        }
    }

    /**
     * Revokes a strategy from being eligible for a vault. This will not affect vaults that
     * are already instantiated with the strategy.
     *
     * If the strategy is already approved, then the transaction will be reverted.
     *
     * @param contractAddr Strategy to be revoked
     */
    function revokeStrategy(address contractAddr) external onlyRole(STRATEGY_MANAGER) {
        if (!strategies[contractAddr]) {
            revert CannotRevokeUnapprovedStrategy(contractAddr);
        }

        strategies[contractAddr] = false;
        emit StrategyRevoked(contractAddr);
    }
}
