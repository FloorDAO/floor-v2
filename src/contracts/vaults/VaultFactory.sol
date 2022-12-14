// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';

import './Vault.sol';
import '../authorities/AuthorityControl.sol';
import '../../interfaces/collections/CollectionRegistry.sol';
import '../../interfaces/strategies/BaseStrategy.sol';
import '../../interfaces/strategies/StrategyRegistry.sol';
import '../../interfaces/vaults/VaultFactory.sol';


/**
 * Allows for vaults to be created, pairing them with a {Strategy} and an approved
 * collection. The vault creation script needs to be as highly optimised as possible
 * to ensure that the gas costs are kept down.
 *
 * This factory will keep an index of created vaults and secondary information to ensure
 * that external applications can display and maintain a list of available vaults.
 *
 * The contract can be paused to prevent the creation of new vaults.
 *
 * Question: Can anyone create a vault?
 */

contract VaultFactory is AuthorityControl, IVaultFactory {

    /// Maintains an array of all vaults created
    address[] private _vaults;

    /// Contract mappings to our internal registries
    ICollectionRegistry public immutable collectionRegistry;
    IStrategyRegistry public immutable strategyRegistry;

    address public immutable vaultImplementation;

    /// Mappings to aide is discoverability
    mapping (uint => address) private vaultIds;
    mapping (address => address[]) private collectionVaults;

    /**
     * Store our registries, mapped to their interfaces.
     */
    constructor (
        address _authority,
        address _collectionRegistry,
        address _strategyRegistry,
        address _vaultImplementation
    ) AuthorityControl(_authority) {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        strategyRegistry = IStrategyRegistry(_strategyRegistry);

        vaultImplementation = _vaultImplementation;
    }

    /**
     * Provides a list of all vaults created.
     */
    function vaults() external view returns (address[] memory) {
        return _vaults;
    }

    /**
     * Provides a vault against the provided `vaultId` (index).
     */
    function vault(uint _vaultId) external view returns (address) {
        return vaultIds[_vaultId];
    }

    /**
     * Provides a list of all vault addresses that have been set up for a
     * collection address.
     */
    function vaultsForCollection(address _collection) external view returns (address[] memory) {
        return collectionVaults[_collection];
    }

    /**
     * Creates a vault with an approved strategy and collection.
     */
    function createVault(
        string memory _name,
        address _strategy,
        bytes memory _strategyInitData,
        address _collection
    ) external returns (
        uint vaultId_,
        address vaultAddr_
    ) {
        // Make sure strategy is approved
        require(strategyRegistry.isApproved(_strategy), 'Strategy not approved');

        // Make sure the collection is approved
        require(collectionRegistry.isApproved(_collection), 'Collection not approved');

        // Capture our vaultId, before we increment the array length
        vaultId_ = _vaults.length;

        // Deploy a new {Strategy} instance using the clone mechanic. We then need to
        // instantiate the strategy using our supplied `strategyInitData`.
        address strategy = Clones.cloneDeterministic(_strategy, bytes32(vaultId_));
        IBaseStrategy(strategy).initialize(vaultId_, _strategyInitData);

        // Create our {Vault} with provided information
        vaultAddr_ = Clones.cloneDeterministic(vaultImplementation, bytes32(vaultId_));
        IVault(vaultAddr_).initialize(_name, vaultId_, _collection, strategy, address(this));

        // Add our vaults to our internal tracking
        _vaults.push(vaultAddr_);

        // Add our mappings for onchain discoverability
        vaultIds[vaultId_] = vaultAddr_;
        collectionVaults[_collection].push(vaultAddr_);

        // Finally we can emit our event to notify watchers of a new vault
        emit VaultCreated(vaultId_, vaultAddr_, _collection);
    }

}
