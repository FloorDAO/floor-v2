// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Handles epoch management for all other contracts.
 */
interface IEpochManager {

    /**
     * ..
     */
    function currentEpoch() external view returns (uint);

    /**
     * ..
     */
    function setCurrentEpoch(uint _currentEpoch) external;

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
    function setContracts(address _collectionRegistry, address _floorWars, address _pricingExecutor, address _treasury, address _vaultFactory, address _voteContract) external;

}
