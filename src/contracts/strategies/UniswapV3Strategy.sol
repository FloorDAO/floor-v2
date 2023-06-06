// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BaseStrategy, InsufficientPosition} from '@floor/strategies/BaseStrategy.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '@floor/utils/Errors.sol';

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';
import {TokenUtils} from '@floor/utils/TokenUtils.sol';

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
        // Set our vault name
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
    /// @param amount0Desired - The desired amount of token0 that should be supplied,
    /// @param amount1Desired - The desired amount of token1 that should be supplied,
    /// @param amount0Min - The minimum amount of token0 that should be supplied,
    /// @param amount1Min - The minimum amount of token1 that should be supplied,
    /// @param deadline - The time by which the transaction must be included to effect the change
    */
    function deposit(
        uint amount0Desired,
        uint amount1Desired,
        uint amount0Min,
        uint amount1Min,
        uint deadline
    ) external returns (
        uint liquidity,
        uint amount0,
        uint amount1
    ) {
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

        // Send leftovers back to the caller
        params.token0.withdrawTokens(msg.sender, amount0Desired - amount0);
        params.token1.withdrawTokens(msg.sender, amount1Desired - amount1);

        // Remove approvals
        params.token0.approveToken(params.positionManager, 0);
        params.token1.approveToken(params.positionManager, 0);

        emit Deposit(params.token0, amount0, msg.sender);
        emit Deposit(params.token1, amount1, msg.sender);

        return (liquidity, amount0, amount1);
    }

    /// @param amount0Min - The minimum amount of token0 that should be accounted for the burned liquidity,
    /// @param amount1Min - The minimum amount of token1 that should be accounted for the burned liquidity,
    /// @param deadline - The time by which the transaction must be included to effect the change
    function withdraw(address recipient, uint amount0Min, uint amount1Min, uint deadline, uint128 liquidity) external nonReentrant onlyOwner {
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
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external view override returns (address[] memory tokens_, uint[] memory amounts_) {
        (,,,,,,,,,, uint128 tokensOwed0, uint128 tokensOwed1) = positionManager.positions(tokenId);
        tokens_ = this.validTokens();
        amounts_ = new uint[](2);
        amounts_[0] = tokensOwed0;
        amounts_[1] = tokensOwed1;
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) external override onlyOwner {
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
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view override returns (address[] memory tokens_) {
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
