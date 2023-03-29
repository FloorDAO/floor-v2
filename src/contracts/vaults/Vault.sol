// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {OwnableUpgradeable} from '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {PausableUpgradeable} from '@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol';

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
error InsufficientPosition(uint amount, uint position);

/**
 * Vaults are responsible for handling end-user token transactions with regards
 * to staking and withdrawal. Each vault will have a registered {Strategy} and
 * {Collection} that it will subsequently interact with and maintain.
 */
contract Vault is IVault, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuard {
    /**
     * The human-readable name of the vault.
     */
    string public name;

    /**
     * The numerical ID of the vault that acts as an index for the {VaultFactory}
     */
    uint public vaultId;

    /**
     * Gets the contract address for the vault collection. Only assets from this contract
     * will be able to be deposited into the contract.
     */
    address public collection;

    /**
     * Gets the contract address for the strategy implemented by the vault.
     */
    IBaseStrategy public strategy;

    /**
     * Maintain a list of active positions held by depositing users.
     */
    uint public position;

    /**
     * The amount of rewards claimed in the last claim call.
     */
    uint public lastEpochRewards;

    /**
     * Set up our vault information.
     *
     * @param _name Human-readable name of the vault
     * @param _collection The address of the collection attached to the vault
     * @param _strategy The strategy implemented by the vault
     */
    function initialize(
        string calldata _name,
        uint _vaultId,
        address _collection,
        address _strategy
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        collection = _collection;
        name = _name;
        strategy = IBaseStrategy(_strategy);
        vaultId = _vaultId;
    }

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     *
     * @param amount Amount of tokens to be deposited by the user
     *
     * @return The amount of xToken received from the deposit
     */
    function deposit(uint amount) external nonReentrant whenNotPaused returns (uint) {
        // Transfer tokens from our user to the vault
        IERC20(collection).transferFrom(msg.sender, address(this), amount);

        // Deposit the tokens into the strategy. This returns the amount of xToken
        // moved into the position for the address.
        IERC20(collection).approve(address(strategy), amount);
        uint receivedAmount = strategy.deposit(amount);
        if (receivedAmount == 0) {
            revert ZeroAmountReceivedFromDeposit();
        }

        // Increase the user's position and the total position for the vault
        unchecked {
            position += receivedAmount;
        }

        // Fire events to stalkers
        emit VaultDeposit(msg.sender, collection, receivedAmount);

        // Return the amount of yield token returned from staking
        return receivedAmount;
    }

    /**
     * Allows the user to exit their position either entirely or partially.
     *
     * @param amount Amount to withdraw
     *
     * @return The amount of tokens returned to the user
     */
    function withdraw(uint amount) external nonReentrant onlyOwner returns (uint) {
        // Ensure we are withdrawing something
        if (amount == 0) {
            revert InsufficientAmount();
        }

        // Ensure our user has sufficient position to withdraw from
        if (amount > position) {
            revert InsufficientPosition(amount, position);
        }

        // Withdraw the user's position from the strategy
        uint receivedAmount = strategy.withdraw(amount);
        if (receivedAmount == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the tokens to the user
        IERC20(collection).transfer(msg.sender, receivedAmount);

        // Fire events to stalkers
        emit VaultWithdrawal(msg.sender, collection, receivedAmount);

        // We can now reduce the users position and total position held by the
        // vault.
        unchecked {
            position -= amount;
        }

        // Return the amount of underlying token returned from staking withdrawal
        return receivedAmount;
    }

    /**
     * Allows the {Treasury} to claim rewards from the vault's strategy.
     *
     * @return The amount of rewards waiting to be minted into {FLOOR}
     */
    function claimRewards() external onlyOwner returns (uint) {
        // Claim any unharvested rewards from the strategy
        lastEpochRewards = strategy.claimRewards();

        // After claiming the rewards we can get a count of how many reward tokens
        // are unminted in the strategy.
        return strategy.unmintedRewards();
    }

    /**
     * ..
     */
    function registerMint(address recipient, uint _amount) external onlyOwner {
        strategy.registerMint(recipient, _amount);
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

}
