// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    uint public constant THRESHOLD = 0;

    /**
     * Sets our internal contracts.
     */
    constructor (
        address _sweepWars,
        address _strategyFactory,
        address _revenueStrategy,
        address _uniswapUniversalRouter
    ) {
        sweepWars = ISweepWars(_sweepWars);
        strategyFactory = StrategyFactory(_strategyFactory);
        revenueStrategy = DistributedRevenueStakingStrategy(_revenueStrategy);
        uniswapUniversalRouter = IUniversalRouter(_uniswapUniversalRouter);
    }

    /**
     * TODO: When the epoch ends, ..
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

            unchecked { ++i; }
        }

        // We then need to calculate the amount we exit our position by, depending on the number
        // of negative votes.
        uint percentage = uint((negativeCollectionVotes / grossVotes) * -1);

        // Ensure we have a negative vote that is past a threshold
        if (percentage > THRESHOLD) {
            return ;
        }

        // We need to determine the holdings across our strategies and exit our positions sufficiently
        // and then subsequently sell against this position for ETH.
        address[] memory strategies = strategyFactory.collectionStrategies(worstCollection);

        // Predefine loop variables
        address[] memory tokens;
        uint[] memory amounts;
        bytes[] memory inputs;

        for (uint i; i < strategies.length;) {
            // Get tokens from strategy
            (tokens, amounts) = strategyFactory.withdrawPercentage(strategies[i], percentage);

            // Set up our data input
            inputs = new bytes[](tokens.length);

            for (uint k; k < tokens.length;) {
                // TODO: Do we need to factor in some slippage?
                inputs[k] = abi.encode(address(this), amounts[k], amounts[k], abi.encodePacked(tokens[k], uint(500), WETH), false);

                unchecked { ++k; }
            }

            // Sends the command to make a V3 token swap
            // @dev https://github.com/Uniswap/universal-router/blob/main/contracts/libraries/Commands.sol
            uniswapUniversalRouter.execute(abi.encodePacked(bytes1(uint8(0x80))), inputs, block.timestamp);

            unchecked { ++i; }
        }

        // Now that we have exited our position, we can move the generated yield into a revenue
        // strategy that will track yield for the next epoch.
        revenueStrategy.depositErc20(WETH.balanceOf(address(this)));
    }

}
