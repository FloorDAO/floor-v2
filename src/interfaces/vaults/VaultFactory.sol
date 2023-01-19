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
    event VaultCreated(uint indexed vaultId, address vaultAddress, address assetAddress);

    /// @dev Sent when a vault is paused or unpaused
    event VaultCreationPaused(bool paused);

    /**
     * Provides a list of all vaults created.
     */
    function vaults() external view returns (address[] memory);

    /**
     * Provides a list of all vaults that reference the approved collection.
     */
    function vaultsForCollection(address _collection) external view returns (address[] memory);

    /**
     * Provides a vault against the provided `vaultId` (index).
     */
    function vault(uint _vaultId) external view returns (address);

    /**
     * Creates a vault with an approved strategy and collection.
     */
    function createVault(string memory _name, address _strategy, bytes memory _strategyInitData, address _collection)
        external
        returns (uint vaultId_, address vaultAddr_);
}
