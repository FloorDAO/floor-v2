// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Allows collection contracts to be approved and revoked by addresses holding the
 * {CollectionManager} role. Only once approved can these collections be applied to
 * new or existing vaults. They will only need to be stored as a mapping of address
 * to boolean.
 */

interface ICollectionRegistry {

    /// Emitted when a collection is successfully approved
    event CollectionApproved(address contractAddr);

    /// Emitted when a collection has been successfully revoked
    event CollectionRevoked(address contractAddr);

    /**
     * Returns `true` if the contract address is an approved collection, otherwise
     * returns `false`.
     */
    function isApproved(address contractAddr) external view returns (bool);

    /**
     * Returns an array of all approved collections.
     */
    function approvedCollections() external view returns (address[] memory);

    /**
     * Approves a collection contract to be used for vaults.
     */
    function approveCollection(address contractAddr) external;

}
