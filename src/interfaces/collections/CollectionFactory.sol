// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Allows collection contracts to be approved and revoked by addresses holding the
 * {CollectionManager} role. Only once approved can these collections be applied to
 * new or existing vaults. They will only need to be stored as an array of addresses.
 */

interface ICollectionFactory {

    /**
     * Provides a collection struct at the stored index.
     */
    function isApproved(address contractAddr) external returns (bool);

    /**
     * Provides a list of all approved collection structs.
     */
    function getApprovedCollections() external returns (address[] memory);

    /**
     * Approves a collection contract to be used for vaults.
     */
    function approveCollection(address contractAddr) external;

    /**
     * Revokes a collection from being eligible for a vault. This cannot be run if a
     * vault is already using this collection.
     */
    function revokeCollection(address contractAddr) external;

}
