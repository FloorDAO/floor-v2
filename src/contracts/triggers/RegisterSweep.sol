// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';


/**
 * If the current epoch is a Collection Addition, then the floor war is ended and the
 * winning collection is chosen. The losing collections are released to be claimed, but
 * the winning collection remains locked for an additional epoch to allow the DAO to
 * exercise the option(s).
 *
 * If the current epoch is just a gauge vote, then we look at the top voted collections
 * and calculates the distribution of yield to each of them based on the vote amounts. This
 * yield is then allocated to a Sweep structure that can be executed by the {Treasury}
 * at a later date.
 *
 * @dev Requires `TREASURY_MANAGER` role.
 * @dev Requires `COLLECTION_MANAGER` role.
 */
contract RegisterSweepTrigger is EpochManaged, IEpochEndTriggered {

    /// Holds our internal contract references
    IBasePricingExecutor public pricingExecutor;
    INewCollectionWars public newCollectionWars;
    ISweepWars public voteContract;
    ITreasury public treasury;
    IStrategyFactory public strategyFactory;

    /// Store our token prices, set by our `pricingExecutor`
    mapping(address => uint) internal tokenEthPrice;

    /// Stores yield generated in the epoch for temporary held calculations
    mapping(address => uint) internal yield;

    /**
     * Define our required contracts.
     */
    constructor (
        address _newCollectionWars,
        address _pricingExecutor,
        address _strategyFactory,
        address _treasury,
        address _voteContract
    ) {
        newCollectionWars = INewCollectionWars(_newCollectionWars);
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        strategyFactory = IStrategyFactory(_strategyFactory);
        treasury = ITreasury(_treasury);
        voteContract = ISweepWars(_voteContract);
    }

    function endEpoch(uint epoch) external onlyEpochManager {

        // Get our strategies
        address[] memory strategies = strategyFactory.strategies();

        // Reset our yield monitoring
        for (uint i; i < strategies.length; i++) {
            yield[strategies[i]] = 0;
        }

        // Get our approved collections
        address[] memory approvedCollections = voteContract.voteOptions();

        /**
         * Query our pricing executor to get our floor price equivalent.
         *
         * Updates our FLOOR <-> token price mapping to determine the amount of FLOOR to allocate
         * as user rewards.
         *
         * The vault will handle its own internal price calculation and stale caching logic based
         * on a {VaultPricingStrategy} tied to the strategy.
         *
         * @dev Our FLOOR ETH price is determined by:
         * https://app.uniswap.org/#/swap?outputCurrency=0xf59257E961883636290411c11ec5Ae622d19455e&inputCurrency=ETH&chain=Mainnet
         *
         * Our token ETH price is determined by (e.g. PUNK):
         * https://app.uniswap.org/#/swap?outputCurrency=0xf59257E961883636290411c11ec5Ae622d19455e&inputCurrency=ETH&chain=Mainnet
         */

        uint[] memory tokenEthPrices = pricingExecutor.getETHPrices(approvedCollections);

        // Iterate through our list and store it to our internal mapping
        for (uint i; i < tokenEthPrices.length;) {
            tokenEthPrice[approvedCollections[i]] = tokenEthPrices[i];
            unchecked { ++i; }
        }

        // Store the amount of rewards generated in ETH
        uint ethRewards;

        // Create our variables that we will reallocate during our loop to save gas
        IBaseStrategy strategy;
        uint tokensLength;

        // Iterate over strategies
        uint strategiesLength = strategies.length;

        // Define our token and amount variables outside of loop
        address[] memory tokens;
        uint[] memory amounts;

        for (uint i; i < strategiesLength;) {
            // Parse our vault address into the Vault interface
            strategy = IBaseStrategy(strategies[i]);

            // Pull out rewards and transfer into the {Treasury}
            uint strategyId = strategy.strategyId();
            (tokens, amounts) = strategyFactory.snapshot(strategyId);

            // Calculate our vault yield and convert it to ETH equivalency that will fund the sweep
            tokensLength = tokens.length;
            for (uint k; k < tokensLength;) {
                if (amounts[k] > 0) {
                    unchecked {
                        ethRewards += tokenEthPrice[tokens[k]] * amounts[k];
                        yield[tokens[k]] += tokenEthPrice[tokens[k]] * amounts[k];
                    }
                }

                unchecked { ++k; }
            }

            unchecked { ++i; }
        }

        // We want the ability to set a minimum sweep amount, so that when we are first
        // starting out the sweeps aren't pathetic.
        uint minSweepAmount = treasury.minSweepAmount();
        if (ethRewards < minSweepAmount) {
            ethRewards = minSweepAmount;
        }

        // If we are currently looking at a new collection addition, rather than a gauge weight
        // vote, then we can bypass additional logic and just end of Floor War.
        if (epochManager.isCollectionAdditionEpoch(epoch)) {
            // At this point we still need to calculate yield, but just attribute it to
            // the winner of the Floor War instead. This will be allocated the full yield amount.
            address collection = newCollectionWars.endFloorWar();

            // Format the collection and amount into the array format that our sweep
            // registration is expecting.
            address[] memory sweepCollections = new address[](1);
            sweepCollections[0] = collection;

            // Allocate the full yield rewards into the single collection
            uint[] memory sweepAmounts = new uint[](1);
            sweepAmounts[0] = ethRewards;

            // Now that we have the results of the new collection addition we can register them
            // against our a pending sweep. This will need to be assigned a "sweep type" to show
            // that it is a Floor War and that we can additionally include "mercenary sweep
            // amounts" in the call.
            treasury.registerSweep(epoch, sweepCollections, sweepAmounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);
        } else {
            // Process the snapshot to find the floor war collection winners and the allocated amount
            // of the sweep.
            (address[] memory collections, uint[] memory snapshotAmounts) = voteContract.snapshot(ethRewards, epoch);

            // We can now remove yield from our collections based on the yield that they generated
            // in the previous epoch.
            for (uint i; i < collections.length;) {
                unchecked {
                    if (snapshotAmounts[i] > yield[collections[i]]) {
                        snapshotAmounts[i] -= yield[collections[i]];
                    } else {
                        snapshotAmounts[i] = 0;
                    }

                    ++i;
                }
            }

            // Now that we have the results of the snapshot we can register them against our
            // pending sweeps.
            treasury.registerSweep(epoch, collections, snapshotAmounts, TreasuryEnums.SweepType.SWEEP);
        }
    }

}
