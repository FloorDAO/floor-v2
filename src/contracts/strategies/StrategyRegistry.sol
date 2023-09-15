// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {IStrategyRegistry} from '@floor-interfaces/strategies/StrategyRegistry.sol';

/**
 * Allows strategy contracts to be approved and revoked by addresses holding the
 * {TREASURY_MANAGER} role. Only once approved can these strategy implementations be deployed
 * to new or existing strategies.
 */
contract StrategyRegistry is AuthorityControl, IStrategyRegistry {
    /// Store a mapping of our approved strategies
    mapping(address => bool) internal _strategies;

    /**
     * Sets up our contract with our authority control to restrict access to
     * protected functions.
     *
     * @param _authority {AuthorityRegistry} contract address
     */
    constructor(address _authority) AuthorityControl(_authority) {}

    /**
     * Checks if a strategy has previously been approved.
     *
     * @param contractAddr The strategy implementation address to be checked
     *
     * @return Returns `true` if the contract address is an approved strategy, otherwise
     * returns `false`.
     */
    function isApproved(address contractAddr) external view returns (bool) {
        return _strategies[contractAddr];
    }

    /**
     * Changes the approval state of a strategy implementation contract.
     *
     * The strategy address cannot be null, and if it is already the new state, then
     * no changes will be made.
     *
     * The caller must have the `TREASURY_MANAGER` role.
     *
     * @param contractAddr Address of unapproved strategy to approve
     * @param approved The new approval state for the implementation
     */
    function approveStrategy(address contractAddr, bool approved) external onlyRole(TREASURY_MANAGER) {
        // Prevent a null contract being added
        if (contractAddr == address(0)) revert CannotSetNullAddress();

        // Check if our strategy is already the new state
        require(_strategies[contractAddr] != approved, 'Strategy is already new state');

        // Update our strategy approval state
        _strategies[contractAddr] = approved;
        emit ApprovedStrategyUpdated(contractAddr, approved);
    }
}
