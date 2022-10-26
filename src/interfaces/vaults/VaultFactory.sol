// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Allows for vaults to be created, pairing them with a {Strategy} and an approved
 * collection. The vault creation script needs to be as highly optimised as possible
 * to ensure that the gas costs are kept down.
 *
 * This factory will keep an index of created vaults and secondary information to ensure
 * that external applications can display and maintain a list of available vaults.
 *
 * The contract can be paused to prevent the creation of new vaults.
 */

interface IVaultFactory {

    /// @dev Sent when a vault is created successfully
    event VaultCreated(uint256 indexed vaultId, address vaultAddress, address assetAddress);

    /**
     * Provides a list of all vaults created.
     */
    function vaults() external view returns (address[] memory);

    /**
     * Provides a vault against the provided `vaultId` (index).
     */
    function vault(uint _vaultId) external view returns (address);

    /**
     * Creates a vault with an approved strategy and collection.
     */
    function createVault(string memory _name, string memory _symbol, address _strategy, address _collection) returns (uint vaultId_, address vaultAddr_);

    /**
     * Allows our governance to pause vaults being create. This should be used
     * if an issue is found in the code until a fix can be put in place.
     */
    function pause(bool pause) external;

}
