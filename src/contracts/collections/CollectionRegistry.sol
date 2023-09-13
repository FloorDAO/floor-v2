// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';

import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';

/// If a zero address strategy tries to be approved
error CannotApproveNullCollection();

/**
 * Allows collection contracts to be approved and revoked by addresses holding the
 * {CollectionManager} role. Only once approved can these collections be applied to
 * new or existing strategies. They will only need to be stored as a mapping of address
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
     * Approves a collection contract to be used for strategies.
     *
     * The collection address cannot be null, and if it is already approved then no changes
     * will be made.
     *
     * The caller must have the `COLLECTION_MANAGER` role.
     *
     * @param contractAddr Address of unapproved collection to approve
     */
    function approveCollection(address contractAddr, address underlyingToken) external onlyRole(COLLECTION_MANAGER) {
        // Prevent a null contract being added
        if (contractAddr == address(0) || underlyingToken == address(0)) {
            revert CannotApproveNullCollection();
        }

        // Check if our collection is already approved to prevent unrequired gas usage
        require(!collections[contractAddr], 'Collection is already approved');

        // Approve our collection
        collections[contractAddr] = true;
        _approvedCollections.push(contractAddr);
        emit CollectionApproved(contractAddr);
    }

    /**
     * Unapproves a collection contract to be used for strategies.
     *
     * This will prevent the collection from being used in any future strategies.
     *
     * The caller must have the `COLLECTION_MANAGER` role.
     *
     * @param contractAddr Address of approved collection to unapprove
     */
    function unapproveCollection(address contractAddr) external onlyRole(COLLECTION_MANAGER) {
        // Ensure that our collection is approved
        require(collections[contractAddr], 'Collection is not approved');

        // Unapprove our collection
        collections[contractAddr] = false;

        // Iterate through our approved collections to find our index to delete
        uint index;
        uint length = _approvedCollections.length;
        for (uint i; i < length;) {
            if (_approvedCollections[i] == contractAddr) {
                index = i;
                break;
            }

            unchecked {
                ++i;
            }
        }

        // Now that we have the index we can move the last item to the deleted position
        // and just pop the array. The array is unordered so this won't be an issue.
        _approvedCollections[index] = _approvedCollections[length - 1];
        _approvedCollections.pop();

        // Emit our event to notify watchers
        emit CollectionRevoked(contractAddr);
    }
}
