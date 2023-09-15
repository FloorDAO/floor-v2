// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Allows strategy contracts to be approved and revoked by addresses holding the
 * {TREASURY_MANAGER} role. Only once approved can these strategy implementations be deployed
 * to new or existing strategies.
 */
interface IStrategyRegistry {
    /// Emitted when a strategy is approved or unapproved
    event ApprovedStrategyUpdated(address contractAddr, bool approved);

    /**
     * Checks if a strategy has previously been approved.
     *
     * @param contractAddr The strategy implementation address to be checked
     *
     * @return Returns `true` if the contract address is an approved strategy, otherwise
     * returns `false`.
     */
    function isApproved(address contractAddr) external view returns (bool);

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
    function approveStrategy(address contractAddr, bool approved) external;
}
