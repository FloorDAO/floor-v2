// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../authorities/AuthorityControl.sol';
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
    address public strategy;

    /**
     * Gets the contract address for the vault factory that created it
     */
    address public vaultFactory;

    /**
     * Store if our Vault is paused, restricting access.
     */
    bool paused;

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
        strategy = _strategy;
        vaultFactory = _vaultFactory;
        vaultId = _vaultId;
    }

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     */
    function deposit(uint amount) external returns (uint256) {
        IERC20(collection).transferFrom(msg.sender, strategy, amount);
        emit VaultDeposit(msg.sender, collection, amount);
        return 0;
    }

    /**
     * Allows the user to exit their position either entirely or partially.
     */
    function withdraw(uint amount) external returns (uint256) {
        IERC20(collection).transferFrom(strategy, msg.sender, amount);
        emit VaultWithdrawal(msg.sender, collection, amount);
        return 0;
    }

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     */
    function pause(bool _pause) external {
        paused = _pause;
    }

}
