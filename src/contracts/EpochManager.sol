// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {IVoteMarket} from '@floor-interfaces/bribes/VoteMarket.sol';
import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {IEpochManager} from '@floor-interfaces/EpochManager.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

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

    /// Store our token prices, set by our `pricingExecutor`
    mapping(address => uint) internal tokenEthPrice;

    /// Holds our internal contract references
    IBasePricingExecutor public pricingExecutor;
    ICollectionRegistry public collectionRegistry;
    INewCollectionWars public newCollectionWars;
    ISweepWars public voteContract;
    ITreasury public treasury;
    IStrategyFactory public strategyFactory;
    IVoteMarket public voteMarket;

    /// Stores a mapping of an epoch to a collection
    mapping(uint => uint) public collectionEpochs;

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
     * Will return if the specified epoch is a collection addition vote.
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

        // Get our strategies
        address[] memory strategies = strategyFactory.strategies();

        /**
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
        if (address(pricingExecutor) == address(0)) {
            revert NoPricingExecutorSet();
        }

        // Get our approved collections
        address[] memory approvedCollections = collectionRegistry.approvedCollections();

        // Query our pricing executor to get our floor price equivalent
        uint[] memory tokenEthPrices = pricingExecutor.getETHPrices(approvedCollections);

        // Iterate through our list and store it to our internal mapping
        for (uint i; i < tokenEthPrices.length;) {
            tokenEthPrice[approvedCollections[i]] = tokenEthPrices[i];
            unchecked {
                ++i;
            }
        }

        // Store the amount of rewards generated in ETH
        uint ethRewards;

        // Create our variables that we will reallocate during our loop to save gas
        IBaseStrategy strategy;
        uint strategyId;
        uint tokensLength;

        // Iterate over strategies
        uint strategiesLength = strategies.length;
        for (uint i; i < strategiesLength;) {
            // Parse our vault address into the Vault interface
            strategy = IBaseStrategy(strategies[i]);

            // Pull out rewards and transfer into the {Treasury}
            strategyId = strategy.strategyId();
            (address[] memory tokens, uint[] memory amounts) = strategyFactory.snapshot(strategyId);

            // Calculate our vault yield and convert it to ETH equivalency that will fund the sweep
            tokensLength = tokens.length;
            for (uint k; k < tokensLength;) {
                if (amounts[k] == 0) {
                    continue;
                }

                unchecked {
                    ethRewards += tokenEthPrice[tokens[k]] * amounts[k];
                    ++k;
                }
            }

            unchecked {
                ++i;
            }
        }

        // We want the ability to set a minimum sweep amount, so that when we are first
        // starting out the sweeps aren't pathetic.
        uint minSweepAmount = treasury.minSweepAmount();
        if (ethRewards < minSweepAmount) {
            ethRewards = minSweepAmount;
        }

        // If we are currently looking at a new collection addition, rather than a gauge weight
        // vote, then we can bypass additional logic and just end of Floor War.
        if (this.isCollectionAdditionEpoch(currentEpoch)) {
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
            treasury.registerSweep(currentEpoch, sweepCollections, sweepAmounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);
        } else {
            // Process the snapshot to find the floor war collection winners and the allocated amount
            // of the sweep.
            (address[] memory collections, uint[] memory amounts) = voteContract.snapshot(ethRewards, currentEpoch);

            // Now that we have the results of the snapshot we can register them against our
            // pending sweeps.
            treasury.registerSweep(currentEpoch, collections, amounts, TreasuryEnums.SweepType.SWEEP);
        }

        unchecked {
            ++currentEpoch;

            // If our lastEpoch is zero, then this is the first epoch ended and we want
            // to set it to the specific block timestamp. Otherwise, we just increase it
            // by the length of the epoch to avoid epoch creep.
            lastEpoch += (lastEpoch == 0) ? block.timestamp : EPOCH_LENGTH;
        }

        // If we have a floor war ready to start, then action it
        if (collectionEpochs[currentEpoch] != 0) {
            newCollectionWars.startFloorWar(collectionEpochs[currentEpoch]);
        }

        emit EpochEnded(currentEpoch - 1, lastEpoch);
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
    function setContracts(
        address _collectionRegistry,
        address _newCollectionWars,
        address _pricingExecutor,
        address _treasury,
        address _strategyFactory,
        address _voteContract,
        address _voteMarket
    ) external onlyOwner {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        newCollectionWars = INewCollectionWars(_newCollectionWars);
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        treasury = ITreasury(_treasury);
        strategyFactory = IStrategyFactory(_strategyFactory);
        voteContract = ISweepWars(_voteContract);
        voteMarket = IVoteMarket(_voteMarket);
    }
}
