// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';
import {BaseStrategy, InsufficientPosition} from '@floor/strategies/BaseStrategy.sol';
import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '@floor/utils/Errors.sol';
import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IUniswapV3Pool} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {FixedPoint128} from '@uniswap-v3/v3-core/contracts/libraries/FixedPoint128.sol';
import {FullMath} from '@uniswap-v3/v3-core/contracts/libraries/FullMath.sol';
import {TickMath} from '@uniswap-v3/v3-core/contracts/libraries/TickMath.sol';
import {LiquidityAmounts} from '@uniswap-v3/v3-periphery/contracts/libraries/LiquidityAmounts.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * Sets up a strategy that interacts with Uniswap.
 */
contract UniswapV3Strategy is BaseStrategy {
    using TokenUtils for address;

    struct InitializeParams {
        address token0;
        address token1;
        uint24 fee;
        uint96 sqrtPriceX96;
        int24 tickLower;
        int24 tickUpper;
        address pool;
        address positionManager;
    }

    /// Once our token has been minted, we can store the ID
    uint public tokenId;

    /// An array of tokens supported by the strategy
    InitializeParams public params;

    /// Stores our Uniswap position manager
    IUniswapV3NonfungiblePositionManager public positionManager;

    /**
     * Sets up our contract variables.
     *
     * @param _name The name of the strategy
     * @param _strategyId ID index of the strategy created
     * @param _initData Encoded data to be decoded
     */
    function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer {
        // Set our strategy name
        name = _name;

        // Set our strategy ID
        strategyId = _strategyId;

        // Extract information from our initialisation bytes data
        params = abi.decode(_initData, (InitializeParams));

        // Cast our position manager to an interface
        positionManager = IUniswapV3NonfungiblePositionManager(params.positionManager);

        // Set the underlying token as valid to process
        _validTokens[params.token0] = true;
        _validTokens[params.token1] = true;

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Adds liquidity against an existing Uniswap ERC721 position.
     *
     * @param amount0Desired - The desired amount of token0 that should be supplied
     * @param amount1Desired - The desired amount of token1 that should be supplied
     * @param amount0Min - The minimum amount of token0 that should be supplied
     * @param amount1Min - The minimum amount of token1 that should be supplied
     * @param deadline - The time by which the transaction must be included to effect the change
     */
    function deposit(uint amount0Desired, uint amount1Desired, uint amount0Min, uint amount1Min, uint deadline)
        external
        nonReentrant
        returns (uint liquidity, uint amount0, uint amount1)
    {
        // Check that we aren't trying to deposit nothing
        if (amount0Desired + amount1Desired == 0) {
            revert CannotDepositZeroAmount();
        }

        // Fetch tokens from address
        uint amount0Pulled = params.token0.pullTokensIfNeeded(msg.sender, amount0Desired);
        uint amount1Pulled = params.token1.pullTokensIfNeeded(msg.sender, amount1Desired);

        // Approve positionManager so it can pull tokens
        params.token0.approveToken(params.positionManager, amount0Pulled);
        params.token1.approveToken(params.positionManager, amount1Pulled);

        // Create our Uniswap pool if it does not already exist
        if (params.pool == address(0)) {
            params.pool = positionManager.createAndInitializePoolIfNecessary(params.token0, params.token1, params.fee, params.sqrtPriceX96);
        }

        // If we don't currently have a token ID for this strategy, then we need to mint one
        // when we first add liquidity.
        if (tokenId == 0) {
            // Create our ERC721 and fund it with an initial desired amount of each token
            (tokenId, liquidity, amount0, amount1) = positionManager.mint(
                IUniswapV3NonfungiblePositionManager.MintParams({
                    token0: params.token0,
                    token1: params.token1,
                    fee: params.fee,
                    tickLower: params.tickLower,
                    tickUpper: params.tickUpper,
                    amount0Desired: amount0Desired,
                    amount1Desired: amount1Desired,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    recipient: address(this),
                    deadline: deadline
                })
            );
        } else {
            // Increase our liquidity position
            (liquidity, amount0, amount1) = positionManager.increaseLiquidity(
                IUniswapV3NonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amount0Desired,
                    amount1Desired: amount1Desired,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: deadline
                })
            );
        }

        // Remove approvals
        params.token0.approveToken(params.positionManager, 0);
        params.token1.approveToken(params.positionManager, 0);

        // Send leftovers back to the caller
        params.token0.withdrawTokens(msg.sender, amount0Desired - amount0);
        params.token1.withdrawTokens(msg.sender, amount1Desired - amount1);

        emit Deposit(params.token0, amount0, msg.sender);
        emit Deposit(params.token1, amount1, msg.sender);

        return (liquidity, amount0, amount1);
    }

    /**
     * Makes a withdrawal of both tokens from our Uniswap token position.
     *
     * @dev Implements `nonReentrant` through `_withdraw`
     *
     * @param recipient The recipient of the withdrawal
     * @param amount0Min The minimum amount of token0 that should be accounted for the burned liquidity
     * @param amount1Min The minimum amount of token1 that should be accounted for the burned liquidity
     * @param deadline The time by which the transaction must be included to effect the change
     * @param liquidity The amount of liquidity to withdraw against
     */
    function withdraw(address recipient, uint amount0Min, uint amount1Min, uint deadline, uint128 liquidity)
        external
        onlyOwner
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        return _withdraw(recipient, amount0Min, amount1Min, deadline, liquidity);
    }

    function _withdraw(address recipient, uint amount0Min, uint amount1Min, uint deadline, uint128 liquidity)
        internal
        nonReentrant
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // If we don't have a token ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (tokenId == 0) {
            return (tokens_, amounts_);
        }

        // Burns liquidity stated, amount0Min and amount1Min are the least you get for
        // burning that liquidity (else reverted).
        (uint amount0, uint amount1) = positionManager.decreaseLiquidity(
            IUniswapV3NonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        // Ensure that we received tokens from our withdraw
        require(amount0 + amount1 != 0, 'No withdraw output');

        // We now need to harvest our tokens as they will be made available to claim
        (uint amount0Collected, uint amount1Collected) = positionManager.collect(
            IUniswapV3NonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: recipient,
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            })
        );

        if (amount0 != 0) {
            emit Withdraw(params.token0, amount0Collected, recipient);
        }

        if (amount1 != 0) {
            emit Withdraw(params.token1, amount1Collected, recipient);
        }

        tokens_ = validTokens();
        amounts_ = new uint[](2);
        amounts_[0] = amount0Collected;
        amounts_[1] = amount1Collected;
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view override returns (address[] memory tokens_, uint[] memory amounts_) {
        tokens_ = validTokens();
        amounts_ = new uint[](2);

        // If we don't have a token ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (tokenId != 0) {

            // Get our token information from our position
            (
                ,,
                address token0,
                address token1,
                ,,,
                uint128 liquidity,
                uint feeGrowthInside0LastX128,
                uint feeGrowthInside1LastX128,
                uint128 positionTokensOwed0,
                uint128 positionTokensOwed1
            ) = positionManager.positions(tokenId);

            // If we have liquidity in our position, then we need additional calculation
            if (liquidity > 0) {
                //
                IUniswapV3Pool pool = IUniswapV3Pool(params.pool);

                // Get our slot0 tick and the global feeGrowth for both tokens
                (, int24 tickCurrent,,,,,) = pool.slot0();
                uint feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
                uint feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();

                // We need to store our inside growth outside of unchecked statement so
                // that it persists.
                uint feeGrowthInside0X128;
                uint feeGrowthInside1X128;

                unchecked {
                    // Get the outside growth from the upper and lower ticks
                    (,, uint feeGrowthOutsideLower0, uint feeGrowthOutsideLower1,,,,) = pool.ticks(params.tickLower);
                    (,, uint feeGrowthOutsideUpper0, uint feeGrowthOutsideUpper1,,,,) = pool.ticks(params.tickUpper);

                    // Calculate fee growth below from the lower tick
                    uint feeGrowthBelow0X128;
                    uint feeGrowthBelow1X128;
                    if (tickCurrent >= params.tickLower) {
                        feeGrowthBelow0X128 = feeGrowthOutsideLower0;
                        feeGrowthBelow1X128 = feeGrowthOutsideLower1;
                    } else {
                        feeGrowthBelow0X128 = feeGrowthGlobal0X128 - feeGrowthOutsideLower0;
                        feeGrowthBelow1X128 = feeGrowthGlobal1X128 - feeGrowthOutsideLower1;
                    }

                    // Calculate fee growth above from the upper tick
                    uint feeGrowthAbove0X128;
                    uint feeGrowthAbove1X128;
                    if (tickCurrent < params.tickUpper) {
                        feeGrowthAbove0X128 = feeGrowthOutsideUpper0;
                        feeGrowthAbove1X128 = feeGrowthOutsideUpper1;
                    } else {
                        feeGrowthAbove0X128 = feeGrowthGlobal0X128 - feeGrowthOutsideUpper0;
                        feeGrowthAbove1X128 = feeGrowthGlobal1X128 - feeGrowthOutsideUpper1;
                    }

                    // Use this to determine the growth inside the range
                    feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
                    feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
                }

                // Calculate the accrued fees for each token
                positionTokensOwed0 += uint128(FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128));
                positionTokensOwed1 += uint128(FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128));
            }

            amounts_[0] = (tokens_[0] == token0) ? uint(positionTokensOwed0) : uint(positionTokensOwed1);
            amounts_[1] = (tokens_[1] == token1) ? uint(positionTokensOwed1) : uint(positionTokensOwed0);

        }

    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) external override onlyOwner {
        // If we don't have a token ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (tokenId == 0) return;

        // Collect fees from the pool
        (uint amount0, uint amount1) = positionManager.collect(
            IUniswapV3NonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: _recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        if (amount0 != 0) {
            lifetimeRewards[params.token0] += amount0;
            emit Harvest(params.token0, amount0);
        }

        if (amount1 != 0) {
            lifetimeRewards[params.token1] += amount1;
            emit Harvest(params.token1, amount1);
        }
    }

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
     *
     * @dev Implements `nonReentrant` through `_withdraw`
     */
    function withdrawPercentage(address /* recipient */, uint /* percentage */) external view override onlyOwner returns (address[] memory, uint[] memory) {
        // We currently don't implement a percentage withdraw for these strategies as it
        // would require on-chain slippage calculation that could be sandwiched.
        return (validTokens(), new uint[](2));
    }

    /**
     * Gets the token balance currently in the Uniswap V3 pool.
     *
     * @return token0Amount The amount of token0 in the pool
     * @return token1Amount The amount of token0 in the pool
     * @return liquidity The amount of liquidity for the tokens
     */
    function tokenBalances() public view returns (uint token0Amount, uint token1Amount, uint128 liquidity) {
        // If we don't have a token ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (tokenId == 0) {
            return (token0Amount, token1Amount, liquidity);
        }

        // Get our `sqrtPriceX96` from the `slot0`
        IUniswapV3Pool pool = IUniswapV3Pool(params.pool);
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Using TickMath, we can get the sqrtRatio for each token
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

        // Get our liquidity for our position
        (,,,,,,, liquidity,,,,) = positionManager.positions(tokenId);

        // Calculate the token amounts for the given liquidity
        (token0Amount, token1Amount) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](2);
        tokens_[0] = params.token0;
        tokens_[1] = params.token1;
    }

    /**
     * Implementing `onERC721Received` so this contract can receive custody of erc721 tokens.
     *
     * @dev Note that the operator is recorded as the owner of the deposited NFT.
     */
    function onERC721Received(address, address, uint, bytes calldata) external view returns (bytes4) {
        // Ensure that the sender of the ERC721 is the Uniswap position manager
        require(msg.sender == address(positionManager), 'Not a Uniswap NFT');

        return this.onERC721Received.selector;
    }
}
