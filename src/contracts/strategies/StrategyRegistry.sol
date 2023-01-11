// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';

import '../authorities/AuthorityControl.sol';
import '../../interfaces/strategies/StrategyRegistry.sol';


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

    constructor (address _authority) AuthorityControl(_authority) {}

    /**
     * Returns `true` if the contract address is an approved strategy, otherwise
     * returns `false`.
     */
    function isApproved(address contractAddr) external view returns (bool) {
        return strategies[contractAddr];
    }

    /**
     * Approves a strategy contract to be used for vaults. The strategy must hold a defined
     * implementation and conform to the {IStrategy} interface.
     */
    function approveStrategy(address contractAddr) external onlyRole(STRATEGY_MANAGER) {
        require(contractAddr != address(0), 'Cannot approve NULL strategy');

        if (!strategies[contractAddr]) {
            strategies[contractAddr] = true;
            emit StrategyApproved(contractAddr);
        }
    }

    /**
     * Revokes a strategy from being eligible for a vault. This will not affect vaults that
     * are already instantiated with the strategy.
     */
    function revokeStrategy(address contractAddr) external onlyRole(STRATEGY_MANAGER) {
        require(strategies[contractAddr], 'Strategy is not approved');

        strategies[contractAddr] = false;
        emit StrategyRevoked(contractAddr);
    }

}
