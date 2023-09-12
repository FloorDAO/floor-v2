// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';

/**
 * When an epoch ends, this contract maintains an indexed list of all collections that
 * were a part of it and the respective vote power attached to each.
 */
contract StoreEpochCollectionVotesTrigger is EpochManaged, IEpochEndTriggered {
    /// Emitted when our collection votes are stored
    event EpochVotesSnapshot(uint epoch, address[] collections, int[] votes);

    /**
     * Holds the data for each epoch to show collections and their votes.
     *
     * @dev The epoch `uint` is required otherwise Solidity breaks as required non-array.
     *
     * @param epoch The epoch the snapshot is taken
     * @param collections The collections that took part in the war
     * @param votes The respective vote power for the collection
     */
    struct EpochSnapshot {
        uint epoch;
        address[] collections;
        int[] votes;
    }

    /// The sweep war contract used by this contract
    ISweepWars public immutable sweepWars;

    /// Store a mapping of epoch to snapshot results
    mapping(uint => EpochSnapshot) internal epochSnapshots;

    /**
     * Sets our internal contracts.
     *
     * @param _sweepWars The {SweepWars} contract being referenced
     */
    constructor(address _sweepWars) {
        if (_sweepWars == address(0)) revert CannotSetNullAddress();
        sweepWars = ISweepWars(_sweepWars);
    }

    /**
     * When the epoch ends, we capture the collections that took part and their respective
     * votes. This is then stored in our mapped structure.
     *
     * @param epoch The epoch that is ending
     */
    function endEpoch(uint epoch) external onlyEpochManager {
        // Get a list of all collections that are part of the vote
        address[] memory collectionAddrs = sweepWars.voteOptions();

        // Get the number of collections to save gas in loops
        uint length = collectionAddrs.length;

        // Create an array ready to store vote amounts, the same length of the collections
        int[] memory collectionVotes = new int[](length);

        // Iterate over our collections and get the votes
        for (uint i; i < length;) {
            // Get the number of votes at the current epoch that is closing
            collectionVotes[i] = sweepWars.votes(collectionAddrs[i]);
            unchecked {
                ++i;
            }
        }

        // Store our epoch snapshots
        epochSnapshots[epoch] = EpochSnapshot(epoch, collectionAddrs, collectionVotes);
        emit EpochVotesSnapshot(epoch, collectionAddrs, collectionVotes);
    }

    /**
     * Public function to get epoch snapshot data.
     */
    function epochSnapshot(uint epoch) external view returns (address[] memory, int[] memory) {
        return (epochSnapshots[epoch].collections, epochSnapshots[epoch].votes);
    }
}
