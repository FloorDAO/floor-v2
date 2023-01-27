// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {OwnableUpgradeable} from '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';

import {VaultXToken} from '../tokens/VaultXToken.sol';
import {InsufficientAmount} from '../utils/Errors.sol';

import {IBaseStrategy} from '../../interfaces/strategies/BaseStrategy.sol';
import {IVault} from '../../interfaces/vaults/Vault.sol';

/// If a protected function is called when the Vault contract is paused
error VaultIsPaused();

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
 *
 * If a user deposits, they won't receive an xToken allocation until the current
 * epoch has ended (called by `migratePendingDeposits` in the {Vault}). This ensures
 * that epochs cannot be sniped by front-running the epoch with a large deposit,
 * claiming a substantial share of the rewards that others generated, and the exiting.
 */
contract Vault is IVault, OwnableUpgradeable, ReentrancyGuard {
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
     * Gets the contract address for the vault factory that created it.
     */
    address public vaultFactory;

    /**
     * Store if our Vault is paused, restricting access.
     */
    bool public paused;

    /**
     * Maintain a mapped list of user positions based on withdrawal and
     * deposits. This will be used to calculate pool share and determine
     * the rewards generated for the user, as well as sense check withdrawal
     * request amounts.
     */
    mapping(address => uint) public pendingPositions;

    /**
     * Maintain a list of addresses with positions. This allows us to iterate
     * our mappings to determine share ownership.
     */
    address[] public pendingStakers;

    /**
     * Stores an address to our vault's {VaultXToken} contract.
     */
    address internal vaultXToken;

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
     * @param _vaultFactory The address of the {VaultFactory} that created the vault
     * @param _vaultXToken The address of the paired xToken
     */
    function initialize(
        string memory _name,
        uint _vaultId,
        address _collection,
        address _strategy,
        address _vaultFactory,
        address _vaultXToken
    ) public initializer {
        __Ownable_init();

        collection = _collection;
        name = _name;
        vaultId = _vaultId;
        strategy = IBaseStrategy(_strategy);
        vaultFactory = _vaultFactory;
        vaultXToken = _vaultXToken;
    }

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     *
     * @param amount Amount of tokens to be deposited by the user
     *
     * @return The amount of xToken received from the deposit
     */
    function deposit(uint amount) external nonReentrant returns (uint) {
        // Ensure that our vault is not paused
        if (paused) {
            revert VaultIsPaused();
        }

        // Transfer tokens from our user to the vault
        IERC20(collection).transferFrom(msg.sender, address(this), amount);

        // Deposit the tokens into the strategy. This returns the amount of xToken
        // moved into the position for the address.
        IERC20(collection).approve(address(strategy), amount);
        uint receivedAmount = strategy.deposit(amount);

        if (receivedAmount == 0) {
            revert ZeroAmountReceivedFromDeposit();
        }

        // Fire events to stalkers
        emit VaultDeposit(msg.sender, collection, receivedAmount);

        // If our user has just entered a position then we add them to
        // our list of addresses.
        if (pendingPositions[msg.sender] == 0) {
            pendingStakers.push(msg.sender);
        }

        // Update our user's position
        pendingPositions[msg.sender] += receivedAmount;

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
    function withdraw(uint amount) external nonReentrant returns (uint) {
        // Ensure we are withdrawing something
        if (amount == 0) {
            revert InsufficientAmount();
        }

        // Ensure our user has sufficient position to withdraw from
        uint userPosition = VaultXToken(vaultXToken).balanceOf(msg.sender) + pendingPositions[msg.sender];
        if (amount > userPosition) {
            revert InsufficientPosition(amount, userPosition);
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

        // Reduce the user's pending position to 0 before looking at the total
        // position. This will ensure that the user exits a pending position and can
        // still receive rewards. We are nice like that.
        uint pendingPosition = pendingPositions[msg.sender];
        if (pendingPosition != 0) {
            if (pendingPosition > amount) {
                pendingPositions[msg.sender] -= amount;
                amount = 0;
            } else {
                amount -= pendingPosition;
                pendingPositions[msg.sender] = 0;
            }
        }

        // If we still have a remaining withdrawal amount then we need to remove it
        // from their active position, which will also affect their vault share.
        if (amount != 0) {
            // Withdraw any pending rewards for the user
            VaultXToken(vaultXToken).withdrawReward(msg.sender);

            // Burn the remaining amount from the user's xToken balance
            VaultXToken(vaultXToken).burnFrom(msg.sender, amount);
        }

        // Return the amount of underlying token returned from staking withdrawal
        return receivedAmount;
    }

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     *
     * @param _pause Boolean value for if the vault should be paused
     */
    function pause(bool _pause) external onlyOwner {
        paused = _pause;
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
     * Migrates any pending depositers and mints their {VaultXToken}s.
     */
    function migratePendingDeposits() external onlyOwner {
        // Calculate our new shares based on new position values
        for (uint i; i < pendingStakers.length;) {
            VaultXToken(vaultXToken).mint(pendingStakers[i], pendingPositions[pendingStakers[i]]);

            // Move our staker's pending position to be an actual position
            pendingPositions[pendingStakers[i]] = 0;

            unchecked {
                ++i;
            }
        }

        // Clear some gas
        delete pendingStakers;
    }

    /**
     * Distributes rewards into the connected {VaultXToken}. This expects that the reward
     * token has already been transferred into the {VaultXToken} contract.
     *
     * @param amount The amount of reward tokens to be distributed into the xToken
     */
    function distributeRewards(uint amount) external onlyOwner {
        // Pass-through function to xToken
        VaultXToken(vaultXToken).distributeRewards(amount);
    }

    /**
     * Returns a publically accessible address for the connected {VaultXToken}.
     *
     * @return {VaultXToken} address
     */
    function xToken() public view returns (address) {
        return vaultXToken;
    }

    /**
     * Returns a user's held position in a vault by referencing their {VaultXToken}
     * balance. Pending deposits will not be included in this return.
     *
     * @param user Address of user to find position of
     *
     * @return The user's non-pending balance
     */
    function position(address user) public view returns (uint) {
        return VaultXToken(vaultXToken).balanceOf(address(user));
    }

    /**
     * Returns the percentage share that the user holds of the vault. This will, in
     * turn, represent the share of rewards that the user is entitled to when the next
     * epoch ends.
     *
     * @param user Address of user to find share of
     *
     * @return Percentage share holding of vault
     */
    function share(address user) public view returns (uint) {
        if (VaultXToken(vaultXToken).totalSupply() == 0) {
            return 0;
        }

        return (VaultXToken(vaultXToken).balanceOf(address(user)) * 10000) / VaultXToken(vaultXToken).totalSupply();
    }
}
