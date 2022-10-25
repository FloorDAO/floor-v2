// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Allows collection contracts to be approved and revoked by addresses holding the
 * {CollectionManager} role. Only once approved can these collections be applied to
 * new or existing vaults.
 */

interface ICollectionFactory {

    /**
     * Allows for our collection contract address reference to be stored, along with
     * a short name that better defines the collection implementation.
     */
    struct Collection {
        bytes32 name;
        address contract;
        bool is1155;
    }

    /**
     * Provides a collection struct at the stored index.
     */
    function getCollection(uint index) external returns (Strategy memory);

    /**
     * Provides a list of all approved collection structs.
     */
    function getCollections() external returns (Strategy[] memory);

    /**
     * Approves a collection contract to be used for vaults.
     */
    function approveCollection(bytes32 name, address contractAddr, bool is1155) external;

    /**
     * Revokes a collection from being eligible for a vault. This cannot be run if a
     * vault is already using this collection.
     */
    function revokeCollection(address contractAddr) external;

}
