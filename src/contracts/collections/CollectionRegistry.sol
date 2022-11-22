// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';

import '../authorities/AuthorityManager.sol';
import '../../interfaces/collections/CollectionRegistry.sol';


/**
 * Allows collection contracts to be approved and revoked by addresses holding the
 * {CollectionManager} role. Only once approved can these collections be applied to
 * new or existing vaults. They will only need to be stored as a mapping of address
 * to boolean.
 */
contract CollectionRegistry is AuthorityManager, ICollectionRegistry {

    /// Store a mapping of our approved collections
    mapping(address => bool) collections;

    /**
     * Returns `true` if the contract address is an approved collection, otherwise
     * returns `false`.
     */
    function isApproved(address contractAddr) external view returns (bool) {
        return collections[contractAddr];
    }

    /**
     * Approves a collection contract to be used for vaults.
     */
    function approveCollection(address contractAddr) external onlyRole(COLLECTION_MANAGER) {
        require(contractAddr != address(0), 'Cannot approve NULL collection');

        if (!collections[contractAddr]) {
            collections[contractAddr] = true;
            emit CollectionApproved(contractAddr);
        }
    }

    /**
     * Revokes a collection from being eligible for a vault. This cannot be run if a
     * vault is already using this collection.
     *
     * @dev This will need updating when our VaultFactory is implemented.
     */
    function revokeCollection(address contractAddr) external onlyRole(COLLECTION_MANAGER) {
        if (collections[contractAddr]) {
            collections[contractAddr] = false;
            emit CollectionRevoked(contractAddr);
        }
    }

}
