// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAuthorityControl {
    /// CollectionManager - Can approve token addresses to be allowed to be used in vaults
    function COLLECTION_MANAGER() external returns (bytes32);

    /// FloorManager - Can mint and manage Floor and VeFloor tokens
    function FLOOR_MANAGER() external returns (bytes32);

    /// Governor - A likely DAO owned vote address to allow for wide scale decisions to
    /// be made and implemented.
    function GOVERNOR() external returns (bytes32);

    /// Guardian - Wallet address that will allow for Governor based actions, except without
    /// timeframe restrictions.
    function GUARDIAN() external returns (bytes32);

    /// TreasuryManager - Access to Treasury asset management
    function TREASURY_MANAGER() external returns (bytes32);

    /// VaultManager - Can create new vaults against approved strategies and collections
    function VAULT_MANAGER() external returns (bytes32);

    /// VoteManager - Can manage account votes
    function VOTE_MANAGER() external returns (bytes32);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns `true` if `account` has been granted either the GOVERNOR or
     * GUARDIAN `role`.
     */
    function hasAdminRole(address account) external view returns (bool);
}
