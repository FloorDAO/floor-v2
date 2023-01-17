// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';

import '../../interfaces/authorities/AuthorityControl.sol';
import '../../interfaces/authorities/AuthorityRegistry.sol';


/**
 * @dev This contract will be heavily based on the standardised OpenZeppelin `AccessControl`
 * library. This will allow for the creation of role based access levels that can be assigned
 * to 1-n addresses. The following roles will need to be created:
 *
 *  - TreasuryManager - Access to Treasury asset management
 *  - VaultManager - Can create new vaults against approved strategies and collections
 *  - VoteManager - Can manage account votes
 *  - StrategyManager - Can approve strategy contracts to be used on vaults
 *  - CollectionManager - Can approve token addresses to be allowed to be used in vaults
 *  - Governor - A likely DAO owned vote address to allow for wide scale decisions to be made and implemented
 *  - Guardian - Wallet address that will allow for Governor based actions, except without timeframe restrictions
 *
 * Contracts will be able to implement the AuthorityControl to provide access to the `onlyRole` modifier or the
 * `hasRole` function. This will ensure that the `msg.sender` has is allowed to perform an action.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed in the external API and be
 * unique. The best way to achieve this is by using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("TreasuryManager");
 * ```
 */
contract AuthorityControl is Context, IAuthorityControl {

    /// Roles are defined for simple and consistent reference.
    bytes32 public constant COLLECTION_MANAGER = keccak256('CollectionManager');
    bytes32 public constant FLOOR_MANAGER = keccak256('FloorManager');
    bytes32 public constant GOVERNOR = keccak256('Governor');
    bytes32 public constant GUARDIAN = keccak256('Guardian');
    bytes32 public constant STRATEGY_MANAGER = keccak256('StrategyManager');
    bytes32 public constant TREASURY_MANAGER = keccak256('TreasuryManager');
    bytes32 public constant VAULT_MANAGER = keccak256('VaultManager');
    bytes32 public constant VOTE_MANAGER = keccak256('VoteManager');

    IAuthorityRegistry public immutable registry;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message if user does not have specified role.
     */
    modifier onlyRole(bytes32 role) {
        require(registry.hasRole(role, _msgSender()), 'Account does not have role');
        _;
    }

    /**
     * @dev Modifier that checks that an account has a governor or guardian role.
     * Reverts with a standardized message if sender does not have an admin role.
     */
    modifier onlyAdminRole() {
        require(registry.hasAdminRole(_msgSender()), 'Account does not have admin role');
        _;
    }

    /**
     * The address that deploys the {AuthorityControl} becomes the default
     * controller. This can only be overwritten by the existing.
     */
    constructor (address _registry) {
        registry = IAuthorityRegistry(_registry);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view override returns (bool) {
        return registry.hasRole(role, account);
    }

    /**
     * @dev Returns `true` if `account` has been granted either the GOVERNOR or
     * GUARDIAN `role`.
     */
    function hasAdminRole(address account) external view returns (bool) {
        return registry.hasAdminRole(account);
    }

}
