// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {Vault} from '@floor/vaults/Vault.sol';
import {CollectionNotApproved} from '@floor/utils/Errors.sol';

import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IVault} from '@floor-interfaces/vaults/Vault.sol';
import {IVaultFactory} from '@floor-interfaces/vaults/VaultFactory.sol';

// No empty names, that's just silly
error VaultNameCannotBeEmpty();

/**
 * Allows for vaults to be created, pairing them with an approved collection. The vault
 * creation script needs to be as highly optimised as possible to ensure that the gas
 * costs are kept down.
 *
 * This factory will keep an index of created vaults and secondary information to ensure
 * that external applications can display and maintain a list of available vaults.
 */
contract VaultFactory is AuthorityControl, IVaultFactory {
    /// Maintains an array of all vaults created
    address[] private _vaults;

    /// Contract mappings to our internal registries
    ICollectionRegistry public immutable collectionRegistry;

    /// Mappings to aide is discoverability
    mapping(uint => address) private vaultIds;
    mapping(address => address[]) private collectionVaults;

    /**
     * Store our registries, mapped to their interfaces.
     *
     * @param _authority {AuthorityRegistry} contract address
     * @param _collectionRegistry Address of our {CollectionRegistry}
     */
    constructor(address _authority, address _collectionRegistry) AuthorityControl(_authority) {
        // Type-cast our interfaces and store our registry contracts
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
    }

    /**
     * Provides a list of all vaults created.
     *
     * @return Array of all vaults created by the {VaultFactory}
     */
    function vaults() external view returns (address[] memory) {
        return _vaults;
    }

    /**
     * Provides a vault against the provided `vaultId` (index). If the index does not exist,
     * then address(0) will be returned.
     *
     * @param _vaultId ID of the vault to cross check
     *
     * @return Address of the vault
     */
    function vault(uint _vaultId) external view returns (address) {
        return vaultIds[_vaultId];
    }

    /**
     * Provides a list of all vault addresses that have been set up for a
     * collection address.
     *
     * @param _collection Address of the collection to look up
     *
     * @return Array of vaults that reference the collection
     */
    function vaultsForCollection(address _collection) external view returns (address[] memory) {
        return collectionVaults[_collection];
    }

    /**
     * Creates a vault with an approved collection.
     *
     * @param _name Human-readable name of the vault
     * @param _strategy The strategy implemented by the vault
     * @param _strategyInitData Bytes data required by the {Strategy} for initialization
     * @param _collection The address of the collection attached to the vault
     *
     * @return vaultId_ ID of the newly created vault
     * @return vaultAddr_ Address of the newly created vault
     */
    function createVault(string calldata _name, address _strategy, bytes calldata _strategyInitData, address _collection)
        external
        onlyRole(VAULT_MANAGER)
        returns (uint vaultId_, address vaultAddr_)
    {
        // No empty names, that's just silly
        if (bytes(_name).length == 0) {
            revert VaultNameCannotBeEmpty();
        }

        // Make sure the collection is approved
        if (!collectionRegistry.isApproved(_collection)) {
            revert CollectionNotApproved(_collection);
        }

        // Capture our vaultId, before we increment the array length
        vaultId_ = _vaults.length;

        // Deploy a new {Strategy} instance using the clone mechanic
        address strategy = Clones.cloneDeterministic(_strategy, bytes32(vaultId_));

        // Create our {Vault} with provided information
        vaultAddr_ = address(new Vault(_name, vaultId_, _collection, strategy));

        // We then need to instantiate the strategy using our supplied `strategyInitData`
        IBaseStrategy(strategy).initialize(vaultId_, vaultAddr_, _strategyInitData);

        // Add our vaults to our internal tracking
        _vaults.push(vaultAddr_);

        // Add our mappings for onchain discoverability
        vaultIds[vaultId_] = vaultAddr_;
        collectionVaults[_collection].push(vaultAddr_);

        // Finally we can emit our event to notify watchers of a new vault
        emit VaultCreated(vaultId_, vaultAddr_, _collection);
    }

    /**
     * ..
     */
    function withdraw(uint _vaultId, uint _amount) public onlyRole(TREASURY_MANAGER) returns (uint) {
        return IVault(vaultIds[_vaultId]).withdraw(_amount);
    }

    /**
     * Allows individual vaults to be paused, meaning that assets can no longer be deposited,
     * although staked assets can always be withdrawn.
     *
     * @dev Events are fired within the vault to allow listeners to update.
     *
     * @param _vaultId Vault ID to be updated
     * @param _paused If the vault should be paused or unpaused
     */
    function pause(uint _vaultId, bool _paused) public onlyRole(VAULT_MANAGER) {
        IVault(vaultIds[_vaultId]).pause(_paused);
    }

    /**
     * ..
     */
    function claimRewards(uint _vaultId) public returns (uint) {
        return IVault(vaultIds[_vaultId]).claimRewards();
    }

    /**
     * ..
     */
    function registerMint(uint _vaultId, uint _amount) public onlyRole(TREASURY_MANAGER) {
        IVault(vaultIds[_vaultId]).registerMint(msg.sender, _amount);
    }
}
