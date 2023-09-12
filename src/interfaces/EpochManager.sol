// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Handles epoch management for all other contracts.
 */
interface IEpochManager {

    /// Emitted when an epoch is ended
    event EpochEnded(uint epoch, uint timestamp);

    /// Emitted when a new collection war is scheduled
    event CollectionAdditionWarScheduled(uint epoch, uint index);

    /// Emitted when required contracts are updated
    event EpochManagerContractsUpdated(address newCollectionWars, address voteMarket);

    /**
     * The current epoch that is running across the codebase.
     *
     * @return The current epoch
     */
    function currentEpoch() external view returns (uint);

    /**
     * Stores a mapping of an epoch to a collection addition war index.
     *
     * @param _epoch Epoch to check
     *
     * @return Index of the collection addition war. Will return 0 if none found
     */
    function collectionEpochs(uint _epoch) external view returns (uint);

    /**
     * Will return if the current epoch is a collection addition vote.
     *
     * @return If the current epoch is a collection addition
     */
    function isCollectionAdditionEpoch() external view returns (bool);

    /**
     * Will return if the specified epoch is a collection addition vote.
     *
     * @param epoch The epoch to check
     *
     * @return If the specified epoch is a collection addition
     */
    function isCollectionAdditionEpoch(uint epoch) external view returns (bool);

    /**
     * Allows an epoch to be scheduled to be a collection addition vote. An index will
     * be specified to show which collection addition will be used. The index will not
     * be a zero value.
     *
     * @param epoch The epoch that the Collection Addition will take place in
     * @param index The Collection Addition array index
     */
    function scheduleCollectionAddtionEpoch(uint epoch, uint index) external;

    /**
     * Triggers an epoch to end.
     *
     * @dev More information about this function can be found in the actual contract
     */
    function endEpoch() external;

    /**
     * Provides an estimated timestamp of when an epoch started, and also the earliest
     * that an epoch in the future could start.
     *
     * @param _epoch The epoch to find the estimated timestamp of
     *
     * @return The estimated timestamp of when the specified epoch started
     */
    function epochIterationTimestamp(uint _epoch) external returns (uint);

    /**
     * The length of an epoch in seconds.
     *
     * @return The length of the epoch in seconds
     */
    function EPOCH_LENGTH() external returns (uint);

    /**
     * Sets contracts that the epoch manager relies on. This doesn't have to include
     * all of the contracts that are {EpochManaged}, but only needs to set ones that the
     * {EpochManager} needs to interact with.
     */
    function setContracts(address _newCollectionWars, address _voteMarket) external;
}
