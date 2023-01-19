// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

import "../../interfaces/authorities/AuthorityRegistry.sol";

/**
 * The {AuthorityRegistry} allows us to assign roles to wallet addresses that we can persist across
 * our various contracts. The roles will offer explicit permissions to perform actions within those
 * contracts.
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and {revokeRole} functions. Only
 * accounts that have an admin role can call {grantRole} and {revokeRole}.
 */
contract AuthorityRegistry is Context, IAuthorityRegistry {
    /// Explicit checks for admin roles required
    bytes32 public constant GOVERNOR = keccak256("Governor");
    bytes32 public constant GUARDIAN = keccak256("Guardian");

    /// Role => Member => Access
    mapping(bytes32 => mapping(address => bool)) private _roles;

    /**
     * The address that deploys the {AuthorityRegistry} becomes the default controller.
     */
    constructor() {
        // Set up our default admin role
        _grantRole(GOVERNOR, _msgSender());
    }

    /**
     * Returns `true` if `account` has been granted `role`.
     *
     * @param role The keccak256 encoded role string
     * @param account Address to check ownership of role
     *
     * @return bool If the address has the specified user role
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        if (role == GOVERNOR) {
            return _roles[role][account];
        }
        return (_roles[role][account] || hasAdminRole(account));
    }

    /**
     * Returns `true` if `account` has been granted either GOVERNOR or GUARDIAN role.
     *
     * @param account Address to check ownership of role
     *
     * @return bool If the address has the GOVERNOR or GUARDIAN role
     */
    function hasAdminRole(address account) public view returns (bool) {
        return (_roles[GOVERNOR][account] || _roles[GUARDIAN][account]);
    }

    /**
     * Grants `role` to `account`. If `account` had not been already granted `role`, emits
     * a {RoleGranted} event.
     *
     * The caller _must_ have an admin role, otherwise the call will be reverted.
     *
     * May emit a {RoleGranted} event.
     *
     * @param role The keccak256 encoded role string
     * @param account Address to grant the role to
     */
    function grantRole(bytes32 role, address account) public virtual override {
        require(hasAdminRole(_msgSender()), "Only admin roles can grant roles");

        if (role == GOVERNOR) {
            require(_roles[GOVERNOR][_msgSender()]);
            require(account != _msgSender());

            _roles[role][_msgSender()] = false;
        }

        _grantRole(role, account);
    }

    /**
     * Handles the internal logic to grant an account a role, if they don't already hold
     * the role being granted.
     *
     * @param role The keccak256 encoded role string
     * @param account Address to grant the role to
     */
    function _grantRole(bytes32 role, address account) internal {
        if (!hasRole(role, account)) {
            _roles[role][account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * Revokes `role` from `account`. If `account` had been granted `role`, emits a
     * {RoleRevoked} event.
     *
     * The caller _must_ have an admin role, otherwise the call will be reverted.
     *
     * May emit a {RoleRevoked} event.
     *
     * @param role The keccak256 encoded role string
     * @param account Address to revoke role from
     */
    function revokeRole(bytes32 role, address account) public virtual override {
        require(hasAdminRole(_msgSender()), "Only admin roles can revoke roles");
        require(role != GOVERNOR, "Governor role cannot be revoked");

        if (hasRole(role, account)) {
            _roles[role][account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * May emit a {RoleRevoked} event.
     *
     * @dev The GOVERNOR role cannot be renounced.
     *
     * @param role The keccak256 encoded role string being revoked
     */
    function renounceRole(bytes32 role) public virtual override {
        require(role != GOVERNOR, "Governor role cannot be renounced");

        if (hasRole(role, _msgSender())) {
            _roles[role][_msgSender()] = false;
            emit RoleRevoked(role, _msgSender(), _msgSender());
        }
    }
}
