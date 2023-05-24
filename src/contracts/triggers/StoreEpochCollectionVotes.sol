// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';

/**
 * ..
 */
contract StoreEpochCollectionVotesTrigger is EpochManaged, IEpochEndTriggered {

    /**
     * ..
     */
    struct EpochSnapshot {
        uint epoch;
        address[] collections;
        int[] votes;
    }

    /// ..
    ISweepWars sweepWars;

    /// Store a mapping of epochs to snapshot results
    mapping(uint => EpochSnapshot) public epochSnapshots;

    /**
     * ..
     */
    constructor (address _sweepWars) {
        sweepWars = ISweepWars(_sweepWars);
    }

    /**
     * ..
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
            collectionVotes[i] = sweepWars.votes(collectionAddrs[i], epoch);
            unchecked { ++i; }
        }

        // Store our epoch snapshots
        epochSnapshots[epoch] = EpochSnapshot(epoch, collectionAddrs, collectionVotes);
    }

}
