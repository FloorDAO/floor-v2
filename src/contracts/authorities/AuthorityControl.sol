// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Context} from '@openzeppelin/contracts/utils/Context.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

/// If the account does not have the required role for the call.
/// @param caller The address making the call
/// @param role The role that is required for the call
error AccountDoesNotHaveRole(address caller, bytes32 role);

/// If the account does not have the required admin role for the call.
/// @param caller The address making the call
error AccountDoesNotHaveAdminRole(address caller);

/**
 * This contract is heavily based on the standardised OpenZeppelin `AccessControl` library.
 * This allows for the creation of role based access levels that can be assigned to 1-n
 * addresses.
 *
 * Contracts will be able to implement the AuthorityControl to provide access to the `onlyRole` modifier or the
 * `hasRole` function. This will ensure that the `msg.sender` is allowed to perform an action.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed in the external API and be
 * unique. The best way to achieve this is by using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("TreasuryManager");
 * ```
 */
contract AuthorityControl is Context, IAuthorityControl {
    /// CollectionManager - Can approve token addresses to be allowed to be used in strategies
    bytes32 public constant COLLECTION_MANAGER = keccak256('CollectionManager');

    /// EpochTrigger - Can run epoch trigger contract specific logic
    bytes32 public constant EPOCH_TRIGGER = keccak256('EpochTrigger');

    /// FloorManager - Can mint and manage Floor and VeFloor tokens
    bytes32 public constant FLOOR_MANAGER = keccak256('FloorManager');

    /// Governor - A likely DAO owned vote address to allow for wide scale decisions to
    /// be made and implemented.
    bytes32 public constant GOVERNOR = keccak256('Governor');

    /// Guardian - Wallet address that will allow for Governor based actions, except without
    /// timeframe restrictions.
    bytes32 public constant GUARDIAN = keccak256('Guardian');

    /// TreasuryManager - Access to Treasury asset management
    bytes32 public constant TREASURY_MANAGER = keccak256('TreasuryManager');

    /// StrategyManager - Can create new strategies against approved strategies and collections
    bytes32 public constant STRATEGY_MANAGER = keccak256('StrategyManager');

    /// VoteManager - Can manage account votes
    bytes32 public constant VOTE_MANAGER = keccak256('VoteManager');

    /// Reference to the {AuthorityRegistry} contract that maintains role allocations
    IAuthorityRegistry public immutable registry;

    /**
     * Modifier that checks that an account has a specific role. Reverts with a
     * standardized message if user does not have specified role.
     *
     * @param role The keccak256 encoded role string
     */
    modifier onlyRole(bytes32 role) {
        if (!registry.hasRole(role, _msgSender())) {
            revert AccountDoesNotHaveRole(_msgSender(), role);
        }
        _;
    }

    /**
     * Modifier that checks that an account has a governor or guardian role.
     * Reverts with a standardized message if sender does not have an admin role.
     */
    modifier onlyAdminRole() {
        if (!registry.hasAdminRole(_msgSender())) {
            revert AccountDoesNotHaveAdminRole(_msgSender());
        }
        _;
    }

    /**
     * The address that deploys the {AuthorityControl} becomes the default controller. This
     * can only be overwritten by the existing.
     *
     * @param _registry The address of our deployed AuthorityRegistry contract
     */
    constructor(address _registry) {
        if (_registry == address(0)) revert CannotSetNullAddress();
        registry = IAuthorityRegistry(_registry);
    }

    /**
     * Returns `true` if `account` has been granted `role`.
     *
     * @param role The keccak256 encoded role string
     * @param account Address to check ownership of role
     *
     * @return bool If the address has the specified user role
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return registry.hasRole(role, account);
    }

    /**
     * Returns `true` if `account` has been granted either GOVERNOR or GUARDIAN role.
     *
     * @param account Address to check ownership of role
     *
     * @return bool If the address has the GOVERNOR or GUARDIAN role
     */
    function hasAdminRole(address account) public view returns (bool) {
        return registry.hasAdminRole(account);
    }
}
