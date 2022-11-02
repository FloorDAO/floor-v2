// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IVault {

    /**
     * @dev This vault will additionally implement the interface of the ERC20 standard
     * as defined in the EIP. This ERC20 token will be used as an xVault token.
     */

    /**
     * Gets the contract address for the vault collection. Only assets from this contract
     * will be able to be deposited into the contract.
     */
    function collection() external view returns (address);

    /**
     * Gets the contract address for the strategy implemented by the vault.
     */
    function strategy() external view returns (address);

    /**
     * Gets the contract address for the vault factory that created it
     */
    function vaultFactory() external view returns (address);

    /**
     * The numerical ID of the vault that acts as an index for the {VaultFactory}
     */
    function vaultId() external view returns (uint256);

    /**
     * Converts token to xToken.
     */
    function deposit(uint amount) external returns (uint256);

    /**
     * Converts xToken to token.
     */
    function withdraw(uint amount, uint[] calldata specificIds) external returns (uint256[] calldata);

}
