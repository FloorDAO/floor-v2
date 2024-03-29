// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EpochManaged} from '@floor/utils/EpochManaged.sol';
import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';

/**
 * When an epoch ends, the vote with the most negative votes will be liquidated to an amount
 * relative to the number of negative votes it received. The amounts will be transferred to
 * the {Treasury} and will need to be subsequently liquidated by a trusted TREASURY_MANAGER.
 */
contract LiquidateNegativeCollectionManualTrigger is EpochManaged, IEpochEndTriggered {

    /// Event fired when losing collection strategy is liquidated
    event CollectionTokensLiquidated(address _worstCollection, address[] _strategies, uint _percentage);

    /// The sweep war contract used by this contract
    ISweepWars public immutable sweepWars;

    /// Internal strategies
    StrategyFactory public immutable strategyFactory;

    /// A threshold percentage that would be worth us working with
    uint public constant THRESHOLD = 1_000; // 1%

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
        address worstCollection;
        int negativeCollectionVotes;
        int grossVotes;

        // Get a list of all collections that are part of the vote
        address[] memory collectionAddrs = sweepWars.voteOptions();

        // Get the number of collections to save gas in loops
        uint length = collectionAddrs.length;

        // Iterate over our collections and get the votes
        for (uint i; i < length;) {
            // Get the number of votes at the current epoch that is closing
            int votes = sweepWars.votes(collectionAddrs[i]);

            // If we have less votes, update our worst collection
            if (votes < negativeCollectionVotes) {
                negativeCollectionVotes = votes;
                worstCollection = collectionAddrs[i];
            }

            // Keep track of the gross number of votes for calculation purposes
            grossVotes += (votes >= 0) ? votes : -votes;

            unchecked {
                ++i;
            }
        }

        // If we have no gross votes, then we cannot calculate a percentage
        if (grossVotes == 0) {
            return;
        }

        // We then need to calculate the amount we exit our position by, depending on the number
        // of negative votes.
        uint percentage = uint(((negativeCollectionVotes * 10000) / grossVotes) * -1);

        // Ensure we have a negative vote that is past a threshold
        if (percentage < THRESHOLD) {
            return;
        }

        // We need to determine the holdings across our strategies and exit our positions sufficiently
        // and then subsequently sell against this position for ETH.
        address[] memory strategies = strategyFactory.collectionStrategies(worstCollection);
        emit CollectionTokensLiquidated(worstCollection, strategies, percentage);
    }
}
