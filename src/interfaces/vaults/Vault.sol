// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

interface IVault {
    /// @dev Emitted when a user deposits
    event VaultDeposit(address depositor, address token, uint amount);

    /// @dev Emitted when a user withdraws
    event VaultWithdrawal(address withdrawer, address token, uint amount);

    /**
     * Gets the contract address for the vault collection. Only assets from this contract
     * will be able to be deposited into the contract.
     */
    function collection() external view returns (address);

    /**
     * Gets the contract address for the strategy implemented by the vault.
     */
    function strategy() external view returns (IBaseStrategy);

    /**
     * The numerical ID of the vault that acts as an index for the {VaultFactory}
     */
    function vaultId() external view returns (uint);

    /**
     * Allows the {Treasury} to claim rewards from the vault's strategy.
     */
    function claimRewards() external returns (uint);

    /**
     * The amount of yield token generated in the last epoch by the vault.
     */
    function lastEpochRewards() external returns (uint);

    /**
     * Allows the user to deposit an amount of tokens that the approved {Collection} and
     * passes it to the {Strategy} to be staked.
     */
    function deposit(uint amount) external returns (uint);

    /**
     * Allows the user to exit their position either entirely or partially.
     */
    function withdraw(uint amount) external returns (uint);

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     */
    function pause(bool pause) external;

    /**
     * ..
     */
    function registerMint(address recipient, uint amount) external;
}
