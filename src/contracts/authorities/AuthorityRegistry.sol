// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';

import '../../interfaces/authorities/AuthorityRegistry.sol';


/**
 * Roles can be granted and revoked dynamically via the {grantRole} and {revokeRole} functions. Each role
 * has an associated admin role, and only accounts that have a role's admin role can call {grantRole}
 * and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means that only accounts with
 * this role will be able to grant or revoke other roles. More complex role relationships can be created
 * by using {_setRoleAdmin}.
 */
contract AuthorityRegistry is Context, IAuthorityRegistry {

    /// Explicit checks for admin roles required
    bytes32 public constant GOVERNOR = keccak256('Governor');
    bytes32 public constant GUARDIAN = keccak256('Guardian');

    /// Role => Member => Access
    mapping(bytes32 => mapping(address => bool)) private _roles;

    /**
     * The address that deploys the {AuthorityRegistry} becomes the default
     * controller. This can only be overwritten by the existing.
     */
    constructor () {
        // Set up our default admin role
        _grantRole(GOVERNOR, _msgSender());
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        if (role == GOVERNOR) {
            return _roles[role][account];
        }
        return (_roles[role][account] || hasAdminRole(account));
    }

    /**
     * @dev Returns `true` if `account` has been granted either the GOVERNOR or
     * GUARDIAN `role`.
     */
    function hasAdminRole(address account) public view returns (bool) {
        return (_roles[GOVERNOR][account] || _roles[GUARDIAN][account]);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override {
        require(hasAdminRole(_msgSender()), 'Only admin roles can grant roles');

        if (role == GOVERNOR) {
            require(_roles[GOVERNOR][_msgSender()]);
            require(account != _msgSender());

            _roles[role][_msgSender()] = false;
        }

        _grantRole(role, account);
    }

    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        require(hasAdminRole(_msgSender()), 'Only admin roles can revoke roles');
        require(role != GOVERNOR, 'Governor role cannot be revoked');

        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role) public virtual override {
        require(role != GOVERNOR, 'Governor role cannot be renounced');

        if (hasRole(role, _msgSender())) {
            _roles[role][_msgSender()] = false;
            emit RoleRevoked(role, _msgSender(), _msgSender());
        }
    }

}
