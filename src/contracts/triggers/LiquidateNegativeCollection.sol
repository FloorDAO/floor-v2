// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {IUniversalRouter} from '@floor-interfaces/uniswap/IUniversalRouter.sol';

/**
 * When an epoch ends, the vote with the most negative votes will be liquidated to an amount
 * relative to the number of negative votes it received.
 */
contract LiquidateNegativeCollectionTrigger is EpochManaged, IEpochEndTriggered {
    IWETH public constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    /// The sweep war contract used by this contract
    ISweepWars public immutable sweepWars;

    StrategyFactory public immutable strategyFactory;
    DistributedRevenueStakingStrategy public immutable revenueStrategy;

    IUniversalRouter public immutable uniswapUniversalRouter;

    /// A threshold percentage that would be worth us working with
    uint public constant THRESHOLD = 1000; // 1%

    /**
     * Holds the data for each epoch to show which collection, if any, received the most
     * negative votes, the number of negative votes it received, and the WETH amount received
     * from the liquidation.
     *
     * @param epoch The epoch the snapshot is taken
     * @param collection The collection with the most negative votes
     * @param votes The vote power received in the epoch
     * @param amount The amount of WETH received from liquidation
     */
    struct EpochSnapshot {
        address collections;
        int votes;
        uint amount;
    }

    /// Store a mapping of epoch to snapshot results
    mapping(uint => EpochSnapshot) public epochSnapshot;

    bytes commands;
    bytes[] inputs;

    /**
     * Sets our internal contracts.
     */
    constructor(address _sweepWars, address _strategyFactory, address _revenueStrategy, address _uniswapUniversalRouter) {
        sweepWars = ISweepWars(_sweepWars);
        strategyFactory = StrategyFactory(_strategyFactory);
        revenueStrategy = DistributedRevenueStakingStrategy(_revenueStrategy);
        uniswapUniversalRouter = IUniversalRouter(_uniswapUniversalRouter);
    }

    /**
     * When the epoch ends, we check to see if any collections received negative votes. If
     * we do, then we find the collection with the most negative votes and liquidate a percentage
     * of the position for that collection based on a formula.
     *
     * @dev The output of the liquidation will be sent to a {DistributedRevenueStakingStrategy}.
     *
     * @param epoch The epoch that is ending
     */
    function endEpoch(uint epoch) external onlyEpochManager {
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
            int votes = sweepWars.votes(collectionAddrs[i], epoch);

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

        // We then need to calculate the amount we exit our position by, depending on the number
        // of negative votes.
        uint percentage = uint(((negativeCollectionVotes * 10000) / grossVotes) * -1);

        // Ensure we have a negative vote that is past a threshold
        if (percentage < THRESHOLD) {
            // If we are below the threshold then we don't register any WETH
            epochSnapshot[epoch] = EpochSnapshot(worstCollection, negativeCollectionVotes, 0);
            return;
        }

        // We need to determine the holdings across our strategies and exit our positions sufficiently
        // and then subsequently sell against this position for ETH.
        address[] memory strategies = strategyFactory.collectionStrategies(worstCollection);

        // Predefine loop variables
        address[] memory tokens;
        uint[] memory amounts;

        for (uint i; i < strategies.length;) {
            // Get tokens from strategy
            (tokens, amounts) = strategyFactory.withdrawPercentage(strategies[i], percentage);

            for (uint k; k < tokens.length;) {
                if (tokens[k] != address(WETH) && amounts[k] != 0) {
                    // commands.push(bytes1(uint8(0x80)));
                    commands.push(bytes1(uint8(0x00)));

                    // TODO: Do we need to factor in some slippage?
                    inputs.push(
                        abi.encode(
                            address(this),
                            amounts[k],
                            0, // Minimum output
                            abi.encodePacked(tokens[k], uint24(10000), address(WETH)),
                            false
                        )
                    );

                    // Transfer the specified amount of token to the universal router
                    IERC20(tokens[k]).transfer(address(uniswapUniversalRouter), amounts[k]);
                }

                unchecked {
                    ++k;
                }
            }

            unchecked {
                ++i;
            }
        }

        // If we had no amounts, then avoid zero deposits
        if (inputs.length != 0) {
            // Sends the command to make a V3 token swap
            uniswapUniversalRouter.execute(commands, inputs, block.timestamp);
        }

        // Ensure that we received WETH
        uint wethBalance = WETH.balanceOf(address(this));
        if (wethBalance != 0) {
            // Now that we have exited our position, we can move the generated yield into a revenue
            // strategy that will track yield for the next epoch.
            WETH.approve(address(revenueStrategy), wethBalance);
            revenueStrategy.depositErc20(wethBalance);
        }

        // Store our epoch snapshot
        epochSnapshot[epoch] = EpochSnapshot(worstCollection, negativeCollectionVotes, wethBalance);

        // Delete storage
        delete commands;
        delete inputs;
    }
}
