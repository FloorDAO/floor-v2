// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IVoteMarket} from '@floor-interfaces/bribes/VoteMarket.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {IEpochManager} from '@floor-interfaces/EpochManager.sol';

/// If the epoch is currently timelocked and insufficient time has passed.
/// @param timelockExpiry The timestamp at which the epoch can next be run
error EpochTimelocked(uint timelockExpiry);

/// If not pricing executor has been set before a call that requires it
error NoPricingExecutorSet();

/**
 * Handles epoch management for all other contracts.
 */
contract EpochManager is IEpochManager, Ownable {
    /// Stores the current epoch that is taking place.
    uint public currentEpoch;

    /// Store a timestamp of when last epoch was run so that we can timelock usage
    uint public lastEpoch;

    /// Store the length of an epoch
    uint public constant EPOCH_LENGTH = 7 days;

    /// Holds our internal contract references
    INewCollectionWars public newCollectionWars;
    IVoteMarket public voteMarket;

    /// Stores a mapping of an epoch to a collection
    mapping(uint => uint) public collectionEpochs;

    /// Store our epoch triggers
    address[] public epochEndTriggers;

    /**
     * Allows a new epoch to be set. This should, in theory, only be set to one
     * above the existing `currentEpoch`.
     *
     * @param _currentEpoch The new epoch to set
     */
    function setCurrentEpoch(uint _currentEpoch) external onlyOwner {
        currentEpoch = _currentEpoch;
    }

    /**
     * Will return if the current epoch is a collection addition vote.
     *
     * @return bool If the current epoch is a collection addition
     */
    function isCollectionAdditionEpoch() external view returns (bool) {
        return collectionEpochs[currentEpoch] != 0;
    }

    /**
     * Will return true if the specified epoch is a collection addition vote.
     *
     * @param epoch The epoch to check
     *
     * @return bool If the specified epoch is a collection addition
     */
    function isCollectionAdditionEpoch(uint epoch) external view returns (bool) {
        return collectionEpochs[epoch] != 0;
    }

    /**
     * Allows an epoch to be scheduled to be a collection addition vote. An index will
     * be specified to show which collection addition will be used. The index will not
     * be a zero value.
     *
     * @param epoch The epoch that the Collection Addition will take place in
     * @param index The Collection Addition array index
     */
    function scheduleCollectionAddtionEpoch(uint epoch, uint index) external {
        require(msg.sender == address(newCollectionWars), 'Invalid caller');
        collectionEpochs[epoch] = index;

        // Handle Vote Market epoch increments
        if (address(voteMarket) != address(0)) {
            voteMarket.extendBribes(epoch);
        }

        emit CollectionAdditionWarScheduled(epoch, index);
    }

    /**
     * Triggers an epoch to end.
     *
     * If the epoch has successfully ended, then the `currentEpoch` value will be increased
     * by one, and the epoch will be locked from updating again until `EPOCH_LENGTH` has
     * passed. We will also check if a new Collection Addition is starting in the new epoch
     * and initialise it if it is.
     */
    function endEpoch() external {
        // Ensure enough time has past since the last epoch ended
        if (lastEpoch != 0 && block.timestamp < lastEpoch + EPOCH_LENGTH) {
            revert EpochTimelocked(lastEpoch + EPOCH_LENGTH);
        }

        // If we have any logic that needs to be triggered when an epoch ends, then we include
        // it here.
        uint triggersLength = epochEndTriggers.length;
        for (uint i; i < triggersLength;) {
            IEpochEndTriggered(epochEndTriggers[i]).endEpoch(currentEpoch);
            unchecked {
                ++i;
            }
        }

        unchecked {
            // If our lastEpoch is zero, then this is the first epoch ended and we want
            // to set it to the specific block timestamp. Otherwise, we just increase it
            // by the length of the epoch to avoid epoch creep.
            lastEpoch += (lastEpoch == 0) ? block.timestamp : EPOCH_LENGTH;
        }

        emit EpochEnded(currentEpoch, lastEpoch);

        unchecked {
            ++currentEpoch;
        }

        // If we have a floor war ready to start, then action it
        if (collectionEpochs[currentEpoch] != 0) {
            newCollectionWars.startFloorWar(collectionEpochs[currentEpoch]);
        }
    }

    /**
     * Allows a new epochEnd trigger to be attached
     */
    function setEpochEndTrigger(address contractAddr, bool enabled) external onlyOwner {
        if (enabled) {
            epochEndTriggers.push(contractAddr);
        } else {
            int deleteIndex = -1;
            uint triggersLength = epochEndTriggers.length;
            for (uint i; i < triggersLength;) {
                if (epochEndTriggers[i] == contractAddr) {
                    deleteIndex = int(i);
                    break;
                }
            }

            require(deleteIndex != -1, 'Not found');
            delete epochEndTriggers[uint(deleteIndex)];
        }
    }

    /**
     * Provides an estimated timestamp of when an epoch started, and also the earliest
     * that an epoch in the future could start.
     *
     * @param _epoch The epoch to find the estimated timestamp of
     *
     * @return uint The estimated timestamp of when the specified epoch started
     */
    function epochIterationTimestamp(uint _epoch) public view returns (uint) {
        if (currentEpoch < _epoch) {
            return lastEpoch + (_epoch * EPOCH_LENGTH);
        }

        if (currentEpoch == _epoch) {
            return lastEpoch;
        }

        return lastEpoch - (_epoch * EPOCH_LENGTH);
    }

    /**
     * Sets the contract addresses of internal contracts that are queried and used
     * in other functions.
     */
    function setContracts(address _newCollectionWars, address _voteMarket) external onlyOwner {
        newCollectionWars = INewCollectionWars(_newCollectionWars);
        voteMarket = IVoteMarket(_voteMarket);
    }
}
