// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';

import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IGaugeWeightVote} from '@floor-interfaces/voting/GaugeWeightVote.sol';

/// If a zero address strategy tries to be approved
error CannotApproveNullCollection();

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

    /// Maintains a contract mapping to our gaugeWeightVote contract to allow us
    /// to keep a sync of approved collections for gas saving.
    IGaugeWeightVote public gaugeWeightVote;

    /// ..
    IBasePricingExecutor public pricingExecutor;

    /// Stores a minimum liquidity threshold that is enforced before a collection can
    /// be approved.
    uint public liquidityThreshold;

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
    function approveCollection(address contractAddr, address underlyingToken) external onlyRole(COLLECTION_MANAGER) {
        // Prevent a null contract being added
        if (contractAddr == address(0) || underlyingToken == address(0)) {
            revert CannotApproveNullCollection();
        }

        // Ensure that we have a linked GWV contract as we need to ensure that collections
        // are synced.
        require(address(gaugeWeightVote) != address(0), 'No GaugeWeightVote contract set');

        // If we haven't already got this collection added, then store it internally
        if (!collections[contractAddr]) {
            // Validate the liquidity of the collection before we can add it
            if (address(pricingExecutor) != address(0) && liquidityThreshold != 0) {
                require(pricingExecutor.getLiquidity(underlyingToken) >= liquidityThreshold, 'Insufficient liquidity');
            }

            // Approve our collection
            collections[contractAddr] = true;
            _approvedCollections.push(contractAddr);
            emit CollectionApproved(contractAddr);

            // Send the newly approved collection to our {GaugeWeightVote} contract for
            // epoch related gas saves.
            gaugeWeightVote.addCollection(contractAddr);
        }
    }

    /**
     * Sets our {GaugeWeightVote} contract address.
     */
    function setGaugeWeightVoteContract(address _gaugeWeightVote) external onlyRole(COLLECTION_MANAGER) {
        gaugeWeightVote = IGaugeWeightVote(_gaugeWeightVote);
    }

    /**
     * Sets our {PricingExecutor} contract address.
     */
    function setPricingExecutor(address _pricingExecutor) external onlyRole(COLLECTION_MANAGER) {
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
    }

    /**
     * Sets our collection liqudity threshold value.
     */
    function setCollectionLiquidityThreshold(uint _liquidityThreshold) external onlyRole(COLLECTION_MANAGER) {
        liquidityThreshold = _liquidityThreshold;
    }
}
