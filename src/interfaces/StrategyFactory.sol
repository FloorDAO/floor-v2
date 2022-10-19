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
     * Allows for our strategy contract address reference to be stored, along with
     * a short name that better defines the strategy implementation.
     */
    struct Strategy {
        bytes32 name;
        address contractAddr;
    }

    /**
     * Provides a strategy struct at the stored index.
     */
    function getStrategy(uint index) external returns (Strategy);

    /**
     * Provides a list of all approved strategy structs.
     */
    function getStrategies() external returns (Strategy[] memory);

    /**
     * Approves a strategy contract to be used for vaults. The strategy must hold a defined
     * implementation and conform to the {IStrategy} interface.
     */
    function approveStrategy(bytes32 name, address contractAddr) external;

    /**
     * Revokes a strategy from being eligible for a vault. This cannot be run if a
     * vault is already using this strategy.
     */
    function revokeStrategy(address contractAddr) external;

}
