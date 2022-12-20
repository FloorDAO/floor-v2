// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../authorities/AuthorityControl.sol';
import '../../interfaces/strategies/BaseStrategy.sol';
import '../../interfaces/vaults/Vault.sol';


contract Vault is AuthorityControl, Initializable, IVault {

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
    bool paused;

    /**
     * Maintain a mapped list of user positions based on withdrawal and
     * deposits. This will be used to calculate pool share and determine
     * the rewards generated for the user, as well as sense check withdrawal
     * request amounts.
     */
    mapping (address => uint) public positions;

    /**
     * Stores the vault share of users based on their owned position.
     */
    mapping (address => uint) public share;

    /**
     * Maintain a list of addresses with positions. This allows us to iterate
     * our mappings to determine share ownership.
     */
    address[] private _awesomePeople;

    /**
     * Maintains a list of our total position to save gas when calculating
     * our address ownership shares.
     */
    uint totalPosition;

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
        IERC20(collection).approve(_strategy, type(uint).max);
    }

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     */
    function deposit(uint amount) external returns (uint) {
        // Ensure that our vault is not paused
        require(!paused, 'Vault is currently paused');

        // Transfer tokens from our user to the vault
        IERC20(collection).transferFrom(msg.sender, address(this), amount);

        // Deposit the tokens into the strategy
        uint receivedAmount = strategy.deposit(amount);
        require(receivedAmount != 0, 'Zero amount received');

        // Fire events to stalkers
        emit VaultDeposit(msg.sender, collection, receivedAmount);

        // If our user has just entered a position then we add them to
        // our list of addresses.
        if (positions[msg.sender] == 0) {
            _awesomePeople.push(msg.sender);
        }

        // Update our user's position
        positions[msg.sender] += receivedAmount;
        totalPosition += receivedAmount;

        // Update our vault share calculation
        _recalculateVaultShare();

        // Return the user's current position
        return positions[msg.sender];
    }

    /**
     * Allows the user to exit their position either entirely or partially.
     */
    function withdraw(uint amount) external returns (uint256) {
        // Ensure we are withdrawing something
        require(amount > 0, 'Insufficient amount requested');

        // Ensure our user has sufficient position to withdraw from
        require(amount <= positions[msg.sender], 'Insufficient position');

        // Withdraw the user's position from the strategy
        strategy.withdraw(amount);

        // Transfer the tokens to the user
        IERC20(collection).transfer(msg.sender, amount);

        // Fire events to stalkers
        emit VaultWithdrawal(msg.sender, collection, amount);

        // Update our user's position
        positions[msg.sender] -= amount;
        totalPosition -= amount;

        // Update our vault share calculation. We update our user's share to 0 as it
        // will be recalculated in the next step and this allows us to handle them fully
        // withdrawing without needing a second iterator in our share recalculation.
        share[msg.sender] = 0;
        _recalculateVaultShare();

        // Return the user's current position
        return positions[msg.sender];
    }

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     */
    function pause(bool _pause) external {
        paused = _pause;
    }

    /**
     * Recalculates the share ownership of each address with a position. This precursory
     * calculation allows us to save gas during epoch calculation.
     *
     * This assumes that when a user enters or exits a position, that their address is
     * maintained correctly in the `_awesomePeople` array.
     */
    function _recalculateVaultShare() internal {
        for (uint i; i < _awesomePeople.length;) {
            if (positions[_awesomePeople[i]] != 0) {
                // 10000 / 290334 / 193556
                // Determine the share to 2 decimal accuracy
                // e.g. 100% = 10000
                share[_awesomePeople[i]] = 100000000 / ((totalPosition * 10000) / (positions[_awesomePeople[i]]));
            }

            unchecked { ++i; }
        }
    }

}
