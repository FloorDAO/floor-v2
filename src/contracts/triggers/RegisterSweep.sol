// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

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
    INewCollectionWars public immutable newCollectionWars;
    ISweepWars public immutable voteContract;
    ITreasury public immutable treasury;
    IStrategyFactory public immutable strategyFactory;

    /// Stores yield generated in the epoch for temporary held calculations
    mapping(address => uint) private _yield;

    /// Temp. stores our epoch tokens that have generated yield
    address[] private _epochTokens;

    /**
     * Define our required contracts.
     */
    constructor(address _newCollectionWars, address _strategyFactory, address _treasury, address _voteContract) {
        if (_newCollectionWars == address(0) || _strategyFactory == address(0) ||
            _treasury == address(0) || _voteContract == address(0)) {
            revert CannotSetNullAddress();
        }

        newCollectionWars = INewCollectionWars(_newCollectionWars);
        strategyFactory = IStrategyFactory(_strategyFactory);
        treasury = ITreasury(_treasury);
        voteContract = ISweepWars(_voteContract);
    }

    /**
     * When our epoch ends, we need to find the tokens yielded from each strategy, as well as
     * the respective amounts.
     */
    function endEpoch(uint epoch) external onlyEpochManager {

        // Capture the amount of ETH / WETH rewards from our strategies
        (,, uint ethRewards) = strategyFactory.snapshot(epoch);

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
            // the winner of the Floor War instead. This will be allocated the full yield
            // amount. Format the collection and amount into the array format that our
            // sweep registration is expecting.
            address[] memory tokens = new address[](1);
            tokens[0] = newCollectionWars.endFloorWar();

            // Allocate the full yield rewards into the single collection
            uint[] memory amounts = new uint[](1);
            amounts[0] = ethRewards;

            // Now that we have the results of the new collection addition we can register them
            // against our a pending sweep. This will need to be assigned a "sweep type" to show
            // that it is a Floor War and that we can additionally include "mercenary sweep
            // amounts" in the call.
            treasury.registerSweep(epoch, tokens, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);
        } else {
            // Process the snapshot to find the floor war collection winners and the allocated amount
            // of the sweep.
            (address[] memory snapshotTokens, uint[] memory snapshotAmounts) = voteContract.snapshot(ethRewards);

            // We can now remove yield from our collections based on the yield that they generated
            // in the previous epoch.
            unchecked {
                // The linked mathematical operation is guaranteed to be performed safely by surrounding
                // conditionals evaluated in either require checks or if-else constructs.
                for (uint i; i < snapshotTokens.length; ++i) {
                    snapshotAmounts[i] = (snapshotAmounts[i] > _yield[snapshotTokens[i]]) ? snapshotAmounts[i] - _yield[snapshotTokens[i]] : 0;
                }
            }

            // Now that we have the results of the snapshot we can register them against our
            // pending sweeps.
            treasury.registerSweep(epoch, snapshotTokens, snapshotAmounts, TreasuryEnums.SweepType.SWEEP);
        }

        // Reset our yield monitoring
        for (uint i; i < _epochTokens.length;) {
            delete _yield[_epochTokens[i]];
            unchecked { ++i; }
        }

        delete _epochTokens;
    }
}
