// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {InsufficientAmount} from '../utils/Errors.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IVault} from '@floor-interfaces/vaults/Vault.sol';

/// If a zero amount is sent to be deposited
error ZeroAmountReceivedFromDeposit();

/// If a zero amount is sent to be withdrawn
error ZeroAmountReceivedFromWithdraw();

/// If the caller has an insufficient position to withdraw from
/// @param amount The amount requested to withdraw
/// @param position The amount available to withdraw for the caller
error InsufficientPosition(address token, uint amount, uint position);

/**
 * Vaults are responsible for handling end-user token transactions with regards
 * to staking and withdrawal. Each vault will have a registered {Strategy} and
 * {Collection} that it will subsequently interact with and maintain.
 */
contract Vault is IVault, Ownable, Pausable, ReentrancyGuard {
    /**
     * The human-readable name of the vault.
     */
    string public name;

    /**
     * The numerical ID of the vault that acts as an index for the {VaultFactory}
     */
    uint public immutable vaultId;

    /**
     * Gets the contract address for the strategy implemented by the vault.
     */
    IBaseStrategy public immutable strategy;

    /**
     * Maintain a list of active positions held by depositing users.
     */
    mapping (address => uint) public position;

    /**
     * The amount of rewards claimed in the last claim call.
     */
    mapping (address => uint) public lastEpochRewards;

    /**
     * Set up our vault information.
     *
     * @param _name Human-readable name of the vault
     * @param _vaultId The deterministic ID assigned to the vault on creation
     * @param _strategy The strategy implemented by the vault
     */
    constructor(string memory _name, uint _vaultId, address _strategy) {
        name = _name;
        vaultId = _vaultId;
        strategy = IBaseStrategy(_strategy);
    }

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     *
     * @param amount Amount of tokens to be deposited by the user
     *
     * @return receivedAmount The amount of xToken received from the deposit
     */
    function deposit(address token, uint amount) external nonReentrant whenNotPaused onlyValidToken(token) returns (uint receivedAmount) {
        // Transfer tokens from our user to the vault
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Deposit the tokens into the strategy. This returns the amount of xToken
        // moved into the position for the address.
        IERC20(token).approve(address(strategy), amount);
        receivedAmount = strategy.deposit(token, amount);
        if (receivedAmount == 0) {
            revert ZeroAmountReceivedFromDeposit();
        }

        // Increase the user's position and the total position for the vault
        unchecked {
            position[token] += receivedAmount;
        }

        // Fire events to stalkers
        emit VaultDeposit(msg.sender, token, receivedAmount);
    }

    /**
     * Allows the user to exit their position either entirely or partially.
     *
     * @param amount Amount to withdraw
     *
     * @return receivedAmount The amount of tokens returned to the user
     */
    function withdraw(address recipient, address token, uint amount) external nonReentrant onlyOwner onlyValidToken(token) returns (uint receivedAmount) {
        // Ensure we are withdrawing something
        if (amount == 0) {
            revert InsufficientAmount();
        }

        // Ensure our user has sufficient position to withdraw from
        if (amount > position[token]) {
            revert InsufficientPosition(token, amount, position[token]);
        }

        // Withdraw the user's position from the strategy
        receivedAmount = strategy.withdraw(token, amount);
        if (receivedAmount == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the tokens to the user
        IERC20(token).transfer(recipient, receivedAmount);

        // Fire events to stalkers
        emit VaultWithdrawal(recipient, token, receivedAmount);

        // We can now reduce the users position and total position held by the
        // vault.
        unchecked {
            position[token] -= amount;
        }
    }

    /**
     * Allows the {Treasury} to claim rewards from the vault's strategy.
     *
     * @return tokens Tokens
     * @return amounts The amount of rewards earned in the epoch
     */
    function claimRewards() external onlyOwner returns (address[] memory tokens, uint[] memory amounts) {
        // Claim any unharvested rewards from the strategy
        (tokens, amounts) = strategy.claimRewards();

        // This will likely only be a single element array, so we just determine the
        // length inline.
        for (uint i; i < tokens.length;) {
            lastEpochRewards[tokens[i]] = amounts[i];

            // After claiming the rewards we can get a count of how many reward tokens
            // are unminted in the strategy. We can also reuse the existing memory array.
            amounts[i] = strategy.unmintedRewards(tokens[i]);

            unchecked { ++i; }
        }
    }

    /**
     * ..
     */
    function registerMint(address recipient, address token, uint amount) external onlyOwner {
        strategy.registerMint(recipient, token, amount);
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

    modifier onlyValidToken(address token) {
        // Validate that the token is valid
        bool valid = false;
        address[] memory validTokens = strategy.tokens();

        for (uint i; i < validTokens.length;) {
            if (validTokens[i] == token) {
                valid = true;
                break;
            }

            unchecked { ++i; }
        }

        require(valid, 'Invalid token');
        _;
    }

}
