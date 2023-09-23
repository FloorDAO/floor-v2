// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {IVoteMarket} from '@floor-interfaces/bribes/VoteMarket.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {IEpochManager} from '@floor-interfaces/EpochManager.sol';

/// If the epoch is currently timelocked and insufficient time has passed.
/// @param timelockExpiry The timestamp at which the epoch can next be run
error EpochTimelocked(uint timelockExpiry);

/**
 * Handles epoch management for all other contracts.
 */
contract EpochManager is IEpochManager, Ownable, ReentrancyGuard {
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
    address[] private _epochEndTriggers;

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
    function endEpoch() external nonReentrant {
        // Ensure enough time has past since the last epoch ended
        if (lastEpoch != 0 && block.timestamp < lastEpoch + EPOCH_LENGTH) {
            revert EpochTimelocked(lastEpoch + EPOCH_LENGTH);
        }

        unchecked {
            // If our lastEpoch is zero, then this is the first epoch ended and we want
            // to set it to the specific block timestamp. Otherwise, we just increase it
            // by the length of the epoch to avoid epoch creep.
            lastEpoch += (lastEpoch == 0) ? block.timestamp : EPOCH_LENGTH;
        }

        // If we have any logic that needs to be triggered when an epoch ends, then we include
        // it here.
        uint triggersLength = _epochEndTriggers.length;
        for (uint i; i < triggersLength;) {
            IEpochEndTriggered(_epochEndTriggers[i]).endEpoch(currentEpoch);
            unchecked {
                ++i;
            }
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
        // If we are trying to add a zero address, exit early
        if (enabled && contractAddr == address(0)) revert CannotSetNullAddress();

        // Both enabling and disabling an `epochEndTrigger` will benefit from
        // knowing the existing index of the `contractAddr`, if it already exists.
        int existingIndex = -1;
        uint triggersLength = _epochEndTriggers.length;
        uint i;
        for (i; i < triggersLength;) {
            if (_epochEndTriggers[i] == contractAddr) {
                existingIndex = int(i);
                break;
            }
            unchecked { ++i; }
        }

        if (enabled) {
            require(existingIndex == -1, 'Trigger already exists');
            _epochEndTriggers.push(contractAddr);
        } else {
            require(existingIndex != -1, 'Trigger not found');

            // Shift the elements after the deleted element by one position
            for (i = uint(existingIndex); i < triggersLength - 1;) {
                _epochEndTriggers[i] = _epochEndTriggers[i + 1];
                unchecked { ++i; }
            }

            // Reduce the length of the array by 1
            _epochEndTriggers.pop();
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
            return lastEpoch + ((_epoch - currentEpoch) * EPOCH_LENGTH);
        }

        if (currentEpoch == _epoch) {
            return lastEpoch;
        }

        return lastEpoch - ((currentEpoch - _epoch) * EPOCH_LENGTH);
    }

    /**
     * Sets the contract addresses of internal contracts that are queried and used
     * in other functions.
     *
     * @dev The vote market contract can be a zero-address as this won't be ready at
     * launch.
     */
    function setContracts(address _newCollectionWars, address _voteMarket) external onlyOwner {
        if (_newCollectionWars == address(0)) revert CannotSetNullAddress();

        newCollectionWars = INewCollectionWars(_newCollectionWars);

        if (_voteMarket != address(0)) {
            voteMarket = IVoteMarket(_voteMarket);
        }

        emit EpochManagerContractsUpdated(_newCollectionWars, _voteMarket);
    }

    /**
     * Provides a complete list of all epoch end triggers, in the order that they
     * are executed.
     */
    function epochEndTriggers() public view returns (address[] memory) {
        return _epochEndTriggers;
    }
}
