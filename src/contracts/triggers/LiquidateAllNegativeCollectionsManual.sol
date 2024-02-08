// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EpochManaged} from '@floor/utils/EpochManaged.sol';
import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';

/**
 * When an epoch ends, any collections with negative votes will be liquidated to an amount
 * relative to the number of negative votes it received.
 */
contract LiquidateAllNegativeCollectionsManualTrigger is EpochManaged, IEpochEndTriggered {

    /// Stores information about any collections with negative votes
    struct NegativeCollection {
        address collection;
        int votes;
    }

    /// Event fired when losing collection strategy is liquidated
    event CollectionTokensLiquidated(address _collection, address[] _strategies, uint _percentage);

    /// The sweep war contract used by this contract
    ISweepWars public immutable sweepWars;

    /// Internal strategies
    StrategyFactory public immutable strategyFactory;

    /**
     * Sets our internal contracts.
     */
    constructor(address _sweepWars, address _strategyFactory) {
        // Prevent any zero-address contracts from being set
        if (_sweepWars == address(0) || _strategyFactory == address(0)) {
            revert CannotSetNullAddress();
        }

        sweepWars = ISweepWars(_sweepWars);
        strategyFactory = StrategyFactory(_strategyFactory);
    }

    /**
     * When the epoch ends, we check to see if any collections received negative votes. If
     * we do, then we find the collection with the most negative votes and liquidate a percentage
     * of the position for that collection based on a formula.
     */
    function endEpoch(uint /* epoch */) external onlyEpochManager {
        // Get a list of all collections that are part of the vote
        address[] memory collectionAddrs = sweepWars.voteOptions();

        // Get the number of collections to save gas in loops
        uint length = collectionAddrs.length;

        // Create an array to store any collection that receives negative votes
        NegativeCollection[] memory negativeCollections = new NegativeCollection[](length);

        // Store our loop variables
        uint total;
        int votes;
        int grossVotes;

        // Iterate over our collections and get the votes
        for (uint i; i < length;) {
            // Get the number of votes at the current epoch that is closing
            votes = sweepWars.votes(collectionAddrs[i]);

            // If we have less votes, update our worst collection
            if (votes < 0) {
                negativeCollections[total] = NegativeCollection({
                    collection: collectionAddrs[i],
                    votes: votes
                });

                unchecked { ++total; }
            }

            // Keep track of the gross number of votes for calculation purposes
            grossVotes += (votes >= 0) ? votes : -votes;

            unchecked { ++i; }
        }

        // If we have no negative collections, we have nothing to process
        if (total == 0) {
            return;
        }

        // Now that we have calculated the gross votes, we can iterate over our negative collections and
        // emit our events.
        for (uint i; i < total;) {
            // We then need to calculate the amount we exit our position by, depending on the number
            // of negative votes.
            uint percentage = uint(((negativeCollections[i].votes * 10000) / grossVotes) * -1);

            // We need to determine the holdings across our strategies and exit our positions sufficiently
            // and then subsequently sell against this position for ETH.
            emit CollectionTokensLiquidated({
                _collection: negativeCollections[i].collection,
                _strategies: strategyFactory.collectionStrategies(negativeCollections[i].collection),
                _percentage: percentage
            });

            unchecked { ++i; }
        }
    }
}
