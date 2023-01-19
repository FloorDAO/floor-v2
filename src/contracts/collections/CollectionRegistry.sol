// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';

import '../authorities/AuthorityControl.sol';
import '../../interfaces/collections/CollectionRegistry.sol';

/**
 * Allows collection contracts to be approved and revoked by addresses holding the
 * {CollectionManager} role. Only once approved can these collections be applied to
 * new or existing vaults. They will only need to be stored as a mapping of address
 * to boolean.
 */
contract CollectionRegistry is AuthorityControl, ICollectionRegistry {
    /// Store a mapping of our approved collections
    mapping(address => bool) internal collections;

    /// Maintains an internal array of approved collections for iteration
    address[] internal _approvedCollections;

    /**
     * Sets up our contract with our authority control to restrict access to
     * protected functions.
     *
     * @param _authority {AuthorityRegistry} contract address
     */
    constructor(address _authority) AuthorityControl(_authority) {}

    /**
     * Checks if a collection has previously been approved.
     *
     * @param contractAddr The collection address to be checked
     *
     * @return Returns `true` if the contract address is an approved collection, otherwise
     * returns `false`.
     */
    function isApproved(address contractAddr) external view returns (bool) {
        return collections[contractAddr];
    }

    /**
     * Returns an array of collection addresses that have been approved.
     *
     * @return address[] Array of collection addresses
     */
    function approvedCollections() external view returns (address[] memory) {
        return _approvedCollections;
    }

    /**
     * Approves a collection contract to be used for vaults.
     *
     * The collection address cannot be null, and if it is already approved then no changes
     * will be made.
     *
     * The caller must have the `COLLECTION_MANAGER` role.
     *
     * @param contractAddr Address of unapproved collection
     */
    function approveCollection(address contractAddr) external onlyRole(COLLECTION_MANAGER) {
        require(contractAddr != address(0), 'Cannot approve NULL collection');

        if (!collections[contractAddr]) {
            collections[contractAddr] = true;
            _approvedCollections.push(contractAddr);
            emit CollectionApproved(contractAddr);
        }
    }
}
