// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Allows strategy contracts to be approved and revoked by addresses holding the
 * {StrategyManager} role. Only once approved can these strategies be applied to
 * new or existing vaults.
 *
 * These strategies will be heavily defined in the {IStrategy} interface, but this
 * Factory focusses solely on managing the list of available vault strategies.
 */

interface IStrategyFactory {

    /**
     * Provides a list of all approved strategy addresses.
     */
    function getStrategies() external returns (address[] memory);

    /**
     * Approves a strategy contract to be used for vaults. The strategy must hold a defined
     * implementation and conform to the {IStrategy} interface.
     */
    function approveStrategy(address contractAddr) external;

    /**
     * Revokes a strategy from being eligible for a vault. This cannot be run if a
     * vault is already using this strategy.
     */
    function revokeStrategy(address contractAddr) external;

}
