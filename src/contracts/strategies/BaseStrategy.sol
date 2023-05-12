// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {InsufficientAmount} from '../utils/Errors.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

/// If a zero amount is sent to be deposited
error ZeroAmountReceivedFromDeposit();

/// If a zero amount is sent to be withdrawn
error ZeroAmountReceivedFromWithdraw();

/// If the caller has an insufficient position to withdraw from
/// @param amount The amount requested to withdraw
/// @param position The amount available to withdraw for the caller
error InsufficientPosition(address token, uint amount, uint position);

/// If the contract was unable to transfer tokens when registering the mint
/// @param recipient The recipient of the token transfer
/// @param amount The amount requested to be transferred
error UnableToTransferTokens(address recipient, uint amount);

/**
 * ..
 */
abstract contract BaseStrategy is IBaseStrategy, Initializable, Ownable, Pausable, ReentrancyGuard {

    /**
     * The human-readable name of the strategy.
     */
    bytes32 public name;

    /**
     * The numerical ID of the vault that acts as an index for the {StrategyFactory}.
     *
     * @dev This must be set in the initializer function call.
     */
    uint public strategyId;

    /**
     * The amount of rewards claimed in the last claim call.
     */
    mapping (address => uint) public lastEpochRewards;

    /**
     * This will return the internally tracked value of tokens that have been harvested
     * by the strategy.
     */
    mapping (address => uint) public lifetimeRewards;

    /**
     * Maintain a list of active positions held by depositing users.
     */
    mapping (address => uint) public position;

    /**
     * Stores a list of tokens that the strategy supports.
     */
    mapping (address => bool) internal _validTokens;

    /**
     * Gets a read of new yield since the last call. This is what can be called when
     * the epoch ends to determine the amount generated within the epoch.
     */
    function snapshot() external /* TODO: onlyRole */ returns (address[] memory tokens_, uint[] memory amounts_) {
        // Get all the available tokens
        (tokens_, amounts_) = this.totalRewards();

        // Find the token difference available
        uint length = amounts_.length;
        for (uint i; i < length;) {
            // Capture the current total rewards for the token
            uint totalRewardsForToken = amounts_[i];

            // Remove the last epoch rewards from our amount returned to show how much
            // additional has been earned in the epoch
            amounts_[i] -= lastEpochRewards[tokens_[i]];

            // We can then update our epoch rewards amount for the token
            lastEpochRewards[tokens_[i]] = totalRewardsForToken;

            unchecked { ++i; }
        }

        // TODO: emit Event();
    }

    /**
     * The total amount of rewards generated by the strategy.
     */
    function totalRewards() external view returns (address[] memory tokens_, uint[] memory amounts_) {
        // Get all the available tokens
        (tokens_, amounts_) = this.available();
        uint tokensLength = tokens_.length;

        // Add our lifetime rewards
        for (uint i; i < tokensLength;) {
            amounts_[i] += lifetimeRewards[tokens_[i]];
            unchecked { ++i; }
        }
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external view virtual returns (address[] memory, uint[] memory) {
        revert('Not implemented');
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action.
     *
     * @dev This _should_ always be imposed to be the {Treasury} by the {StrategyFactory}.
     */
    function harvest(address /* _recipient */) external virtual /* TODO: onlyRole */ {
        revert('Not implemented');
    }

    /**
     * Returns an array of tokens that the strategy supports.
     *
     * @return address[] The address of valid tokens
     */
    function validTokens() external view virtual returns (address[] memory) {
        revert('Not implemented');
    }

    /**
     * Pauses deposits from being made into the strategy.
     *
     * @dev This should only be called by a guardian or governor.
     *
     * @param _p Boolean value for if the vault should be paused
     */
    function pause(bool _p) external onlyOwner {
        if (_p) _pause();
        else _unpause();
    }

    /**
     * Confirms that the requested tokens are all valid before processing a function.
     *
     * @param tokens An array of tokens that must all be valid
     */
    modifier onlyValidTokens(address[] memory tokens) {
        // Iterate over tokens to ensure that they are registered as valid. If they
        // aren't then we will revert the call before processing.
        uint length = tokens.length;
        for (uint i; i < length;) {
            require(_validTokens[tokens[i]], 'Invalid token');
            unchecked { ++i; }
        }

        _;
    }

}
