// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';

import '../../interfaces/authorities/AuthorityManager.sol';


/**
 * @dev This contract will be heavily based on the standardised OpenZeppelin `AccessControl`
 * library. This will allow for the creation of role based access levels that can be assigned
 * to 1-n addresses. The following roles will need to be created:
 *
 *  - TreasuryManager - Access to Treasury asset management
 *  - VaultManager - Can create new vaults against approved strategies and collections
 *  - StrategyManager - Can approve strategy contracts to be used on vaults
 *  - CollectionManager - Can approve token addresses to be allowed to be used in vaults
 *  - Governor - A likely DAO owned vote address to allow for wide scale decisions to be made and implemented
 *  - Guardian - Wallet address that will allow for Governor based actions, except without timeframe restrictions
 *
 * Contracts will be able to implement the AuthorityManager to provide access to the `onlyRole` modifier or the
 * `hasRole` function. This will ensure that the `msg.sender` has is allowed to perform an action.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed in the external API and be
 * unique. The best way to achieve this is by using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("TreasuryManager");
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and {revokeRole} functions. Each role
 * has an associated admin role, and only accounts that have a role's admin role can call {grantRole}
 * and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means that only accounts with
 * this role will be able to grant or revoke other roles. More complex role relationships can be created
 * by using {_setRoleAdmin}.
 */
contract AuthorityManager is AccessControl, IAuthorityManager {

    bytes32 public constant TREASURY_MANAGER = keccak256('TreasuryManager');
    bytes32 public constant VAULT_MANAGER = keccak256('VaultManager');
    bytes32 public constant STRATEGY_MANAGER = keccak256('StrategyManager');
    bytes32 public constant COLLECTION_MANAGER = keccak256('CollectionManager');
    bytes32 public constant GOVERNOR = keccak256('Governor');
    bytes32 public constant GUARDIAN = keccak256('Guardian');

    constructor() {
        // Set up our default admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Create our initial roles
        _grantRole(TREASURY_MANAGER, msg.sender);
        _grantRole(VAULT_MANAGER, msg.sender);
        _grantRole(STRATEGY_MANAGER, msg.sender);
        _grantRole(COLLECTION_MANAGER, msg.sender);
        _grantRole(GOVERNOR, msg.sender);
        _grantRole(GUARDIAN, msg.sender);
    }

}
