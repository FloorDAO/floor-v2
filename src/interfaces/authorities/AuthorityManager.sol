// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


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

interface IAuthorityManager {

   /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     */
    function renounceRole(bytes32 role) external;

    /**
     * A helper function to check if a role currently exists in the system.
     */
    function roleExists(bytes32 role) external view returns (bool);

}
