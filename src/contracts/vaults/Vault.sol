// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../authorities/AuthorityControl.sol';

import '../../interfaces/strategies/BaseStrategy.sol';
import '../../interfaces/vaults/Vault.sol';


contract Vault is AuthorityControl, Initializable, IVault, ReentrancyGuard {

    address TREASURY;

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
    mapping (address => uint) public positions;
    mapping (address => uint) public pendingPositions;

    /**
     * Stores the vault share of users based on their owned position.
     */
    mapping (address => uint) public share;

    /**
     * Maintain a list of addresses with positions. This allows us to iterate
     * our mappings to determine share ownership.
     */
    address[] public stakers;

    /**
     * Maintains a list of our total position to save gas when calculating
     * our address ownership shares.
     */
    uint public totalPosition;
    uint public totalPendingPosition;

    /**
     * ...
     */
    constructor (address _authority) AuthorityControl(_authority) {}

    /**
     * ...
     */
    function initialize(
        string memory _name,
        uint _vaultId,
        address _collection,
        address _strategy,
        address _vaultFactory
    ) public initializer {
        collection = _collection;
        name = _name;
        strategy = IBaseStrategy(_strategy);
        vaultFactory = _vaultFactory;
        vaultId = _vaultId;

        // Give our collection max approval
        IERC20(_collection).approve(_strategy, type(uint).max);
    }

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     */
    function deposit(uint amount) external nonReentrant returns (uint) {
        // Ensure that our vault is not paused
        require(!paused, 'Vault is currently paused');

        // Transfer tokens from our user to the vault
        IERC20(collection).transferFrom(msg.sender, address(this), amount);

        // Deposit the tokens into the strategy. This returns the amount of xToken
        // moved into the position for the address.
        uint receivedAmount = strategy.deposit(amount);
        require(receivedAmount != 0, 'Zero amount received');

        // Fire events to stalkers
        emit VaultDeposit(msg.sender, collection, receivedAmount);

        // If our user has just entered a position then we add them to
        // our list of addresses.
        if (positions[msg.sender] == 0) {
            stakers.push(msg.sender);
        }

        // Update our user's position
        pendingPositions[msg.sender] += receivedAmount;
        totalPendingPosition += receivedAmount;

        // Return the amount of yield token returned from staking
        return receivedAmount;
    }

    /**
     * Allows the user to exit their position either entirely or partially.
     */
    function withdraw(uint amount) external nonReentrant returns (uint) {
        // Ensure we are withdrawing something
        require(amount > 0, 'Insufficient amount requested');

        // Ensure our user has sufficient position to withdraw from
        require(amount <= positions[msg.sender] + pendingPositions[msg.sender], 'Insufficient position');

        // Withdraw the user's position from the strategy
        uint receivedAmount = strategy.withdraw(amount);
        require(receivedAmount != 0, 'Zero amount received');

        // Transfer the tokens to the user
        IERC20(collection).transfer(msg.sender, receivedAmount);

        // Fire events to stalkers
        emit VaultWithdrawal(msg.sender, collection, receivedAmount);

        // Reduce the user's pending position to 0 before looking at the total
        // position. This will ensure that the user exits a pending position and can
        // still receive rewards. We are nice like that.
        if (pendingPositions[msg.sender] != 0) {
            if (pendingPositions[msg.sender] > amount) {
                pendingPositions[msg.sender] -= amount;
                totalPendingPosition -= amount;
                amount = 0;
            }
            else {
                amount -= pendingPositions[msg.sender];
                totalPendingPosition -= pendingPositions[msg.sender];
                pendingPositions[msg.sender] = 0;
            }
        }

        // If we still have a remaining withdrawal amount then we need to remove it
        // from their active position, which will also affect their vault share.
        if (amount != 0) {
            totalPosition -= amount;
            positions[msg.sender] -= amount;

            // Update our vault share calculation. We update our user's share to 0 as it
            // will be recalculated in the next step and this allows us to handle them fully
            // withdrawing without needing a second iterator in our share recalculation.
            share[msg.sender] = 0;
            this.recalculateVaultShare(false);
        }

        // Return the amount of underlying token returned from staking withdrawal
        return receivedAmount;
    }

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     */
    function pause(bool _pause) external onlyRole(VAULT_MANAGER) {
        paused = _pause;
    }

    /**
     *
     */
    function shares(bool excludeTreasury) external view returns (address[] memory, uint[] memory) {
        address[] memory users = new address[](stakers.length);
        uint[] memory percentages = new uint[](stakers.length);

        for (uint i; i < stakers.length;) {
            if (!excludeTreasury || stakers[i] == TREASURY) {
                // TODO: Allow treasury to be excluded
                users[i] = stakers[i];
                percentages[i] = share[stakers[i]];
            }

            unchecked { ++i; }
        }

        return (users, percentages);
    }

    function claimRewards() external returns (uint) {
        // Claim any unharvested rewards from the strategy
        strategy.claimRewards();
        uint amount = strategy.unmintedRewards();
        // TODO: Transfer to treasury?
        strategy.registerMint(amount);
        return amount;
    }

    /**
     * Recalculates the share ownership of each address with a position. This precursory
     * calculation allows us to save gas during epoch calculation.
     *
     * This assumes that when a user enters or exits a position, that their address is
     * maintained correctly in the `stakers` array.
     */
    function recalculateVaultShare(bool updatePending) external {
        if (updatePending) {
            // Update our total positions, moving the pending position into the total and
            // then resetting the pending value to 0.
            totalPosition += totalPendingPosition;
            totalPendingPosition = 0;
        }

        // Calculate our new shares based on new position values
        for (uint i; i < stakers.length;) {
            // Move our stakers pending position to be an actual position
            if (updatePending && pendingPositions[stakers[i]] != 0) {
                positions[stakers[i]] += pendingPositions[stakers[i]];
                pendingPositions[stakers[i]] = 0;
            }

            if (positions[stakers[i]] != 0) {
                // Determine the share to 2 decimal accuracy
                // e.g. 100% = 10000
                share[stakers[i]] = 100000000 / ((totalPosition * 10000) / (positions[stakers[i]]));
            }

            unchecked { ++i; }
        }
    }

}
