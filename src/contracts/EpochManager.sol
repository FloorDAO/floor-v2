// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {IVoteMarket} from '@floor-interfaces/bribes/VoteMarket.sol';
import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IVault} from '@floor-interfaces/vaults/Vault.sol';
import {IVaultFactory} from '@floor-interfaces/vaults/VaultFactory.sol';
import {IFloorWars} from '@floor-interfaces/voting/FloorWars.sol';
import {IGaugeWeightVote} from '@floor-interfaces/voting/GaugeWeightVote.sol';
import {IEpochManager} from '@floor-interfaces/EpochManager.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

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
    IFloorWars public floorWars;
    IGaugeWeightVote public voteContract;
    ITreasury public treasury;
    IVaultFactory public vaultFactory;
    IVoteMarket public voteMarket;

    /// Stores a mapping of an epoch to a collection
    mapping (uint => uint) internal collectionEpochs;

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
        require(msg.sender == address(floorWars), 'Invalid caller');
        collectionEpochs[epoch] = index;

        // Handle Vote Market epoch increments
        voteMarket.extendBribes(epoch);
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

        // If we are currently looking at a new collection addition, rather than a gauge weight
        // vote, then we can bypass additional logic and just end of Floor War.
        if (this.isCollectionAdditionEpoch(currentEpoch)) {
            floorWars.endFloorWar();
        }
        else {
            // Get our vaults
            address[] memory vaults = vaultFactory.vaults();

            /**
             * Updates our FLOOR <-> token price mapping to determine the amount of FLOOR to allocate
             * as user rewards.
             *
             * The vault will handle its own internal price calculation and stale caching logic based
             * on a {VaultPricingStrategy} tied to the vault.
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
            IVault vault;
            uint vaultId;
            uint vaultYield;

            // Iterate over vaults
            uint vaultLength = vaults.length;
            for (uint i; i < vaultLength;) {
                // Parse our vault address into the Vault interface
                vault = IVault(vaults[i]);

                // Pull out rewards and transfer into the {Treasury}
                vaultId = vault.vaultId();
                vaultYield = vaultFactory.claimRewards(vaultId);

                if (vaultYield != 0) {
                    // Calculate the reward yield in FLOOR token terms
                    unchecked {
                        ethRewards += tokenEthPrice[vault.collection()] * vaultYield;
                    }

                    // Now that the {Treasury} has knowledge of the reward tokens and has minted
                    // the equivalent FLOOR, we can notify the {Strategy} and transfer assets into
                    // the {Treasury}.
                    vaultFactory.registerMint(vaultId, vaultYield);
                }

                unchecked {
                    ++i;
                }
            }

            if (ethRewards != 0) {
                // We want the ability to set a minimum sweep amount, so that when we are first
                // starting out the sweeps aren't pathetic.
                uint minSweepAmount = treasury.minSweepAmount();
                if (minSweepAmount != 0 && ethRewards < minSweepAmount) {
                    ethRewards = minSweepAmount;
                }

                // Process the snapshot
                (address[] memory collections, uint[] memory amounts) = voteContract.snapshot(ethRewards, currentEpoch);

                // Now that we have the results of the snapshot we can register them against our
                // pending sweeps.
                treasury.registerSweep(currentEpoch, collections, amounts);
            }
        }

        unchecked {
            ++currentEpoch;
            lastEpoch += EPOCH_LENGTH;
        }

        // If we have a floor war ready to start, then action it
        if (collectionEpochs[currentEpoch] != 0) {
            floorWars.startFloorWar(collectionEpochs[currentEpoch]);
        }

        // emit EpochEnded(lastEpoch);
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
        address _floorWars,
        address _pricingExecutor,
        address _treasury,
        address _vaultFactory,
        address _voteContract,
        address _voteMarket
    ) external onlyOwner {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        floorWars = IFloorWars(_floorWars);
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        treasury = ITreasury(_treasury);
        vaultFactory = IVaultFactory(_vaultFactory);
        voteContract = IGaugeWeightVote(_voteContract);
        voteMarket = IVoteMarket(_voteMarket);
    }

}
