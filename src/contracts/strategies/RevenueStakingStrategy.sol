// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BaseStrategy, InsufficientPosition} from '@floor/strategies/BaseStrategy.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '../utils/Errors.sol';


/**
 * Supports manual staking of "yield" from an authorised sender. This allows manual
 * yield management from external sources and products that cannot be strictly enforced
 * on-chain otherwise.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality.
 *
 * @dev This staking strategy will only accept ERC20 deposits and withdrawals.
 */
contract RevenueStakingStrategy is BaseStrategy {

    /// An array of tokens supported by the strategy
    address[] private _tokens;

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
        (_tokens) = abi.decode(_initData, (address[]));

        // Set the underlying token as valid to process
        for (uint i; i < _tokens.length;) {
          _validTokens[_tokens[i]] = true;
          unchecked { ++i; }
        }

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Deposit a token that will be stored as a reward.
     *
     * @param amount Amount of token to deposit
     *
     * @return uint Amount of token registered as rewards
     */
    function depositErc20(address token, uint amount) external nonReentrant whenNotPaused onlyValidToken(token) returns (uint) {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Transfer the underlying token from our caller
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // We increase our lifetime rewards by the amount deposited
        lifetimeRewards[token] += amount;

        // Emit our event to followers. We need to emit both a `Deposit` and `Harvest` as this
        // strategy essentially merges the two.
        emit Deposit(token, amount, amount, msg.sender);
        emit Harvest(token, amount);

        // As we have a 1:1 mapping of tokens, we can just return the initial deposit amount
        return amount;
    }

    /**
     * Withdraws an amount of our position from the strategy.
     *
     * @param amount Amount of token to withdraw
     *
     * @return uint Amount of the token returned
     */
    function withdrawErc20(address recipient, address token, uint amount) external nonReentrant onlyOwner onlyValidToken(token) returns (uint) {
        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        // Capture our starting balance
        uint startTokenBalance = IERC20(token).balanceOf(address(this));

        // Ensure our user has sufficient position to withdraw from
        if (amount > startTokenBalance) {
            revert InsufficientPosition(token, amount, startTokenBalance);
        }

        // Transfer the received token to the caller
        IERC20(token).transfer(recipient, amount);

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(token, amount, msg.sender);

        // As we have a 1:1 mapping of tokens, we can just return the initial withdrawal amount
        return amount;
    }

    /**
     * Gets rewards that are available to harvest.
     *
     * @dev This will always return two empty arrays as we will never have
     * tokens available to harvest.
     */
    function available() external view override returns (address[] memory tokens_, uint[] memory amounts_) {
        tokens_ = _tokens;
        amounts_ = new uint[](_tokens.length);
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) external override onlyOwner {
        /*  */
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view override returns (address[] memory) {
        return _tokens;
    }

}
