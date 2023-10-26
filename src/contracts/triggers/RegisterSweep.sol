// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
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
    IBasePricingExecutor public immutable pricingExecutor;
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
    constructor(address _newCollectionWars, address _pricingExecutor, address _strategyFactory, address _treasury, address _voteContract) {
        if (_newCollectionWars == address(0) || _pricingExecutor == address(0) || _strategyFactory == address(0) ||
            _treasury == address(0) || _voteContract == address(0)) {
            revert CannotSetNullAddress();
        }

        newCollectionWars = INewCollectionWars(_newCollectionWars);
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        strategyFactory = IStrategyFactory(_strategyFactory);
        treasury = ITreasury(_treasury);
        voteContract = ISweepWars(_voteContract);
    }

    /**
     * When our epoch ends, we need to find the tokens yielded from each strategy, as well as
     * the respective amounts. We will then call our {PricingExecutor} to find the ETH value of
     * each token. If the WETH token is called, then it will automatically map this as a 1:1.
     *
     * We then find the ETH values of the tokens that are yielded.
     */
    function endEpoch(uint epoch) external onlyEpochManager {

        // Get our strategies
        address[] memory strategies = strategyFactory.strategies();

        uint ethRewards;
        IBaseStrategy strategy;
        address[] memory tokens;
        uint[] memory amounts;

        // Loop through our strategies to capture yielded tokens and amounts
        uint strategiesLength = strategies.length;
        for (uint i; i < strategiesLength;) {
            // Parse our strategy address into the {BaseStrategy} interface
            strategy = IBaseStrategy(strategies[i]);

            // Pull out rewards and transfer into the {Treasury}
            (tokens, amounts) = strategyFactory.snapshot(strategy.strategyId(), epoch);

            for (uint k; k < tokens.length;) {
                if (amounts[k] != 0) {
                    if (_yield[tokens[k]] == 0) {
                        _epochTokens.push(tokens[k]);
                    }

                    _yield[tokens[k]] += amounts[k];
                }

                unchecked { ++k; }
            }

            unchecked { ++i; }
        }

        // Get the tokens that have been generated as yield and find their ETH price
        uint[] memory tokenEthPrices = pricingExecutor.getETHPrices(_epochTokens);

        // We can now iterate over the eth prices of the tokens. These are returned in the
        // same order that they are requested, so we can directly access the yield and
        // multiply it based on the token decimal count.
        for (uint i; i < tokenEthPrices.length;) {
            uint ethValue = tokenEthPrices[i] * _yield[_epochTokens[i]] / (10 ** ERC20(_epochTokens[i]).decimals());

            // We can then modify the stored yield to store the ETH value, rather than the
            // amount in relative terms of the token.
            _yield[_epochTokens[i]] = ethValue;

            // This logic should be replicated for tests in: `test_CanHandleDifferentSweepTokenDecimalAccuracy`
            ethRewards += ethValue;

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
            // the winner of the Floor War instead. This will be allocated the full yield
            // amount. Format the collection and amount into the array format that our
            // sweep registration is expecting.
            tokens = new address[](1);
            tokens[0] = newCollectionWars.endFloorWar();

            // Allocate the full yield rewards into the single collection
            amounts = new uint[](1);
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
