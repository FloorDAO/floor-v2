// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import {EpochManaged} from '@floor/utils/EpochManaged.sol';
import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {IUniversalRouter} from '@floor-interfaces/uniswap/IUniversalRouter.sol';

/**
 * When an epoch ends, the vote with the most negative votes will be liquidated to an amount
 * relative to the number of negative votes it received.
 *
 * The ERC20 token will be moved to a Sudoswap pool with a high ETH price that slowly
 * declines. When a purchase is made the pool price will increase and so on. If the pool
 * holds no tokens when additional tokens are added then we will additionally reset the
 * spot price to avoid undervaluations.
 *
 * ETH received from the transactions will be sent directly to a revenue strategy for yield
 * distribution over the coming epochs.
 *
 * When setting the spot price we will use a pricing executor to find the initial price with
 * a small multiplier applied.
 */
contract SudoswapLiquidateNegativeCollectionTrigger is EpochManaged, IEpochEndTriggered, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// WETH address interface
    IWETH public immutable WETH;

    /// The sweep war contract used by this contract
    ISweepWars public immutable sweepWars;

    /// Internal strategies
    StrategyFactory public immutable strategyFactory;
    DistributedRevenueStakingStrategy public immutable revenueStrategy;

    /// The executor used to determine the liquidation price
    IBasePricingExecutor public pricingExecutor;

    /// A threshold percentage that would be worth us working with
    uint public constant THRESHOLD = 1_000; // 1%

    /**
     * Holds the data for each epoch to show which collection, if any, received the most
     * negative votes, the number of negative votes it received, and the WETH amount received
     * from the liquidation.
     *
     * @param collection The collection with the most negative votes
     * @param votes The vote power received in the epoch
     * @param amount The amount of WETH received from liquidation
     */
    struct PoolFunded {
        address collection;
        address pool;
        address token;
        uint amount;
    }

    /// Store a mapping of fundings against an epoch
    mapping (uint => PoolFunded[]) public epochSnapshot;

    /// Store a mapping of underlying tokens to Sudoswap pool addresses
    mapping (address => address) public sudoswapPools;

    /**
     * Sets our internal contracts.
     */
    constructor(
        address _pricingExecutor,
        address _sweepWars,
        address _strategyFactory,
        address _revenueStrategy,
        address _weth
    ) {
        // Prevent any zero-address contracts from being set
        if (_pricingExecutor == address(0) || _sweepWars == address(0) || _strategyFactory == address(0) ||
            _revenueStrategy == address(0) || _weth == address(0)) {
            revert CannotSetNullAddress();
        }

        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        sweepWars = ISweepWars(_sweepWars);
        strategyFactory = StrategyFactory(_strategyFactory);
        revenueStrategy = DistributedRevenueStakingStrategy(_revenueStrategy);
        WETH = IWETH(_weth);
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
    function endEpoch(uint epoch) external onlyEpochManager nonReentrant {
        // Determine the worst collection and other required variables associated to it
        (address worstCollection, uint grossVotes, int negativeCollectionVotes, uint percentage) = _worstCollection();

        // If we have no gross votes, then we cannot calculate a percentage
        if (grossVotes == 0) {
            return;
        }

        // Ensure we have a negative vote that is past a threshold
        if (percentage < THRESHOLD) {
            return;
        }

        // Get a collection of tokens and amounts that will be added to Sudoswap pools
        (address[] memory tokens, uint[] memory amounts) = _getLiquidationTokensAndAmounts(worstCollection, percentage);

        // We then iterate over our tokens and deposit them into a Sudoswap pool
        for (uint i; i < tokens.length; ++i) {
            _createOrFundPool(tokens[i], amounts[i]);

            // Record the amount of tokens added to the pool
            epochSnapshot[epoch] = PoolFunded({
                collection: worstCollection,
                pool: sudoswapPools[tokens[i]],
                token: tokens[i],
                amount: amounts[i]
            });
        }
    }

    /**
     * Determines the collection that received the most negative votes from an epoch
     * and the percentage that needs to be withdrawed from the corresponding strategies.
     *
     * @return worstCollection The collection with the most negative votes
     * @return grossVotes The total number of all votes cast
     * @return negativeCollectionVotes The number of negative votes received by the collection
     * @return percentage The amount to be withdrawn from strategies
     */
    function _worstCollection() private returns (
        address worstCollection,
        int grossVotes,
        int negativeCollectionVotes,
        uint percentage
    ) {
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

        // We then need to calculate the amount we exit our position by, depending on the number
        // of negative votes.
        percentage = uint(((negativeCollectionVotes * 10000) / grossVotes) * -1);
    }

    /**
     * Determines the tokens and amounts that will be liquidated
     */
    function _getLiquidationTokensAndAmounts(address collection, uint percentage) private returns (address[] memory tokens, uint[] memory amounts) {
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
                    // Add our swap command to the stack
                    commands.push(bytes1(uint8(0x00)));

                    // Add our swap parameters
                    inputs.push(
                        abi.encode(
                            // [address] The recipient of the output of the trade
                            address(this),
                            // [uint] The amount of input tokens for the trade
                            amounts[k],
                            // [uint] Get the WETH value of the token amounts that we will expect
                            // to receive back from our swap, minus a slippage percentage.
                            pricingExecutor.getETHPrice(tokens[k]) * amounts[k] * (100_000 - slippage) / 100_000, // Minimum output
                            // [bytes] The UniswapV3 encoded path to trade along
                            abi.encodePacked(tokens[k], uint24(10000), address(WETH)),
                            // [bool] A flag for whether the input tokens should come from the msg.sender
                            // (through Permit2) or whether the funds are already in the UniversalRouter
                            false
                        )
                    );

                    // Transfer the specified amount of token to the universal router
                    IERC20(tokens[k]).safeTransfer(address(uniswapUniversalRouter), amounts[k]);
                }

                unchecked {
                    ++k;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _createOrFundPool(address token, uint amount) private {
            // If we don't yet have a SudoSwap pool defined, we need to set one up
            if (sudoswapPools[token] == address(0)) {
                // Map our collection to a newly created pair
                sudoswapPools[token] = pairFactory.createPairERC20(
                    IERC20(sudoswapPools[token]),  // _nft
                    gdaCurve,                 // _bondingCurve
                    treasury,                 // _assetRecipient
                    LSSVMPair.PoolType.TOKEN, // _poolType
                    (uint128(alphaAndLambda) << 48) + uint128(uint48(block.timestamp)), // _delta
                    0,                        // _fee
                    initialSpotPrice,         // _spotPrice
                    address(0),               // _propertyChecker
                    new uint[](0)             // _initialNFTIDs
                );
            }
            // Otherwise, if we already have a mapped address, we can instead just deposit
            // additional tokens into it.
            else {
                // When we provide additional ETH, we need to reset the spot price and delta
                // to ensure that we aren't sweeping above market price.
                LSSVMPairETH pair = sweeperPools[collections[i]];

                uint pairBalance = payable(pair).balance;
                if (pair.spotPrice() > pairBalance) {
                    // If the pair balance is below the initial starting threshold, then we will
                    // reset the spot price to that as a minimum.
                    if (pairBalance < initialSpotPrice) {
                        pairBalance = initialSpotPrice;
                    }

                    // Update the spot price to either the current pair balance (before deposit)
                    // or to the initial spot price defined by the contract.
                    pair.changeSpotPrice(uint128(pairBalance));

                    // Update the delta back to the initial price
                    pair.changeDelta((uint128(alphaAndLambda) << 48) + uint128(uint48(block.timestamp)));
                }

                // Deposit ETH to pair
                (bool sent,) = payable(pair).call{value: amounts[i]}('');
                if (!sent) revert TransferFailed();
            }
    }
}
