// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../strategies/BaseStrategy.sol';

interface IVault {
    /// @dev Emitted when a user deposits
    event VaultDeposit(address depositor, address token, uint amount);

    /// @dev Emitted when a user withdraws
    event VaultWithdrawal(address withdrawer, address token, uint amount);

    /**
     * ...
     */
    function initialize(
        string memory _name,
        uint _vaultId,
        address _collection,
        address _strategy,
        address _vaultFactory,
        address _vaultXToken
    ) external;

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
     * Gets the contract address for the vault factory that created it
     */
    function vaultFactory() external view returns (address);

    /**
     * The numerical ID of the vault that acts as an index for the {VaultFactory}
     */
    function vaultId() external view returns (uint);

    /**
     * TODO: ..
     */
    function claimRewards() external returns (uint);

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
     * Recalculates the share ownership of each address with a position. This precursory
     * calculation allows us to save gas during epoch calculation.
     *
     * This assumes that when a user enters or exits a position, that their address is
     * maintained correctly in the `stakers` array.
     */
    function migratePendingDeposits() external;

    /**
     * ..
     */
    function xToken() external returns (address);

    function distributeRewards(uint amount) external;

}
