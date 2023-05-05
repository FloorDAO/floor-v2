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
     * Maintain a list of active positions held by depositing users.
     */
    mapping (address => uint) public position;

    /**
     * The amount of rewards claimed in the last claim call.
     */
    mapping (address => uint) public lastEpochRewards;

    /**
     * This will return the internally tracked value of tokens that have been minted into
     * FLOOR by the {Treasury}.
     */
    mapping (address => uint) public mintedRewards;

    /**
     * This will return the internally tracked value of tokens that have been claimed by
     * the strategy, regardless of if they have been minted into FLOOR.
     */
    mapping (address => uint) public lifetimeRewards;

    /**
     * Stores a list of tokens that the strategy supports.
     */
    mapping (address => bool) public _validTokens;

    /**
     * Allows the {Treasury} to claim rewards from the vault's strategy.
     *
     * @return tokens Tokens
     * @return amounts The amount of rewards earned in the epoch
     */
    function claimRewards() external onlyOwner returns (address[] memory tokens, uint[] memory amounts) {
        // Claim any unharvested rewards from the strategy
        (tokens, amounts) = _claimRewards();

        // This will likely only be a single element array, so we just determine the
        // length inline.
        for (uint i; i < tokens.length;) {
            lastEpochRewards[tokens[i]] = amounts[i];

            // After claiming the rewards we can get a count of how many reward tokens
            // are unminted in the strategy. We can also reuse the existing memory array.
            amounts[i] = this.unmintedRewards(tokens[i]);

            unchecked { ++i; }
        }
    }

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     *
     * @param _p Boolean value for if the vault should be paused
     */
    function pause(bool _p) external onlyOwner {
        if (_p) _pause();
        else _unpause();
    }

    /// @dev Overridden functions
    function _claimRewards() internal virtual returns (address[] memory, uint[] memory) { revert('Not implemented'); }
    function unmintedRewards(address /*token */) external virtual view returns (uint) { revert('Not implemented'); }

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
