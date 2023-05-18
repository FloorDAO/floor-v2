// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Handles epoch management for all other contracts.
 */
interface IEpochManager {
    event EpochEnded(uint epoch, uint timestamp);
    event CollectionAdditionWarScheduled(uint epoch, uint index);

    /**
     * ..
     */
    function currentEpoch() external view returns (uint);

    function collectionEpochs(uint) external view returns (uint);

    /**
     * ..
     */
    function setCurrentEpoch(uint _currentEpoch) external;

    /**
     * ..
     */
    function isCollectionAdditionEpoch() external view returns (bool);

    /**
     * ..
     */
    function isCollectionAdditionEpoch(uint epoch) external view returns (bool);

    /**
     * ..
     */
    function scheduleCollectionAddtionEpoch(uint epoch, uint index) external;

    /**
     * ..
     */
    function endEpoch() external;

    /**
     * ..
     */
    function epochIterationTimestamp(uint) external returns (uint);

    /**
     * ..
     */
    function EPOCH_LENGTH() external returns (uint);

    /**
     * ..
     */
    function setContracts(
        address _collectionRegistry,
        address _newCollectionWars,
        address _pricingExecutor,
        address _treasury,
        address _vaultFactory,
        address _voteContract,
        address _voteMarket
    ) external;
}
