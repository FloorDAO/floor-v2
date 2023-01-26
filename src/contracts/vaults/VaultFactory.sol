// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {AuthorityControl} from '../authorities/AuthorityControl.sol';
import {VaultXToken} from '../tokens/VaultXToken.sol';

import {ICollectionRegistry} from '../../interfaces/collections/CollectionRegistry.sol';
import {IBaseStrategy} from '../../interfaces/strategies/BaseStrategy.sol';
import {IStrategyRegistry} from '../../interfaces/strategies/StrategyRegistry.sol';
import {IVault} from '../../interfaces/vaults/Vault.sol';
import {IVaultFactory} from '../../interfaces/vaults/VaultFactory.sol';

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

    /// Implementation addresses that will be cloned
    address public immutable vaultImplementation;
    address public immutable vaultXTokenImplementation;

    /// Mappings to aide is discoverability
    mapping(uint => address) private vaultIds;
    mapping(address => address[]) private collectionVaults;

    /// Internal contract references
    address public floor;
    address public staking;

    /**
     * Store our registries, mapped to their interfaces.
     *
     * @param _authority {AuthorityRegistry} contract address
     * @param _collectionRegistry Address of our {CollectionRegistry}
     * @param _strategyRegistry Address of our {StrategyRegistry}
     * @param _vaultImplementation Address of our deployed {Vault} to clone
     * @param _vaultXTokenImplementation Address of our deployed {VaultXToken} to clone
     * @param _floor Address of our {FLOOR}
     */
    constructor(
        address _authority,
        address _collectionRegistry,
        address _strategyRegistry,
        address _vaultImplementation,
        address _vaultXTokenImplementation,
        address _floor
    ) AuthorityControl(_authority) {
        // Sense check that our contracts don't have NULL addresses
        require(_collectionRegistry != address(0), '_collectionRegistry cannot be NULL');
        require(_strategyRegistry != address(0), '_strategyRegistry cannot be NULL');
        require(_floor != address(0), 'FLOOR token cannot be NULL');

        // Type-cast our interfaces and store our registry contracts
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        strategyRegistry = IStrategyRegistry(_strategyRegistry);

        // Store our implementation addresses
        vaultImplementation = _vaultImplementation;
        vaultXTokenImplementation = _vaultXTokenImplementation;

        // Store our FLOOR token address
        floor = _floor;
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
     * Creates a vault with an approved strategy, collection and corresponding {VaultXToken}.
     *
     * @param _name Human-readable name of the vault
     * @param _strategy The strategy implemented by the vault
     * @param _strategyInitData Bytes data required by the {Strategy} for initialization
     * @param _collection The address of the collection attached to the vault
     *
     * @return vaultId_ ID of the newly created vault
     * @return vaultAddr_ Address of the newly created vault
     */
    function createVault(string memory _name, address _strategy, bytes memory _strategyInitData, address _collection)
        external
        onlyRole(VAULT_MANAGER)
        returns (uint vaultId_, address vaultAddr_)
    {
        // Ensure our {VeFloorStaking} contract address has been set
        require(staking != address(0), 'Staking contract cannot be NULL');

        // No empty names, that's just silly
        require(bytes(_name).length != 0, 'Name cannot be empty');

        // Make sure strategy is approved
        require(strategyRegistry.isApproved(_strategy), 'Strategy not approved');

        // Make sure the collection is approved
        require(collectionRegistry.isApproved(_collection), 'Collection not approved');

        // Capture our vaultId, before we increment the array length
        vaultId_ = _vaults.length;

        // Deploy a new {Strategy} instance using the clone mechanic
        address strategy = Clones.cloneDeterministic(_strategy, bytes32(vaultId_));

        // Determine our deployed addresses
        vaultAddr_ = Clones.cloneDeterministic(vaultImplementation, bytes32(vaultId_));
        address vaultXTokenAddr_ = Clones.cloneDeterministic(vaultXTokenImplementation, bytes32(vaultId_));

        // Create our {Vault} with provided information
        IVault(vaultAddr_).initialize(_name, vaultId_, _collection, strategy, address(this), vaultXTokenAddr_);

        // Create our {VaultXToken} for the vault
        VaultXToken(vaultXTokenAddr_).initialize(floor, staking, _name, _name);

        // Transfer our ownership of the the VaultXToken from the {VaultFactory} to the {Vault}
        // that we have created.
        VaultXToken(vaultXTokenAddr_).transferOwnership(vaultAddr_);

        // We then need to instantiate the strategy using our supplied `strategyInitData`
        IBaseStrategy(strategy).initialize(vaultId_, vaultAddr_, _strategyInitData);

        // Add our vaults to our internal tracking
        _vaults.push(vaultAddr_);

        // Add our mappings for onchain discoverability
        vaultIds[vaultId_] = vaultAddr_;
        collectionVaults[_collection].push(vaultAddr_);

        // Finally we can emit our event to notify watchers of a new vault
        emit VaultCreated(vaultId_, vaultAddr_, vaultXTokenAddr_, _collection);
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
     * Updates pending stakers into active stakers, entitling them to a share of the
     * vault rewards yield.
     *
     * @dev This should be called when an epoch is ended.
     *
     * @param _vaultId Vault ID to be updated
     */
    function migratePendingDeposits(uint _vaultId) public onlyRole(VAULT_MANAGER) {
        IVault(vaultIds[_vaultId]).migratePendingDeposits();
    }

    /**
     * Distributes rewards into the {VaultXToken} via the {Vault}.
     *
     * @param _vaultId Vault ID to be updated
     * @param _amount Amount of reward tokens to be distributed
     */
    function distributeRewards(uint _vaultId, uint _amount) public onlyRole(REWARDS_MANAGER) {
        IVault(vaultIds[_vaultId]).distributeRewards(_amount);
    }

    /**
     * Allows the staking contract to be updated.
     *
     * @param _staking Contract address of the staking contract to be set
     */
    function setStakingContract(address _staking) public onlyRole(VAULT_MANAGER) {
        staking = _staking;
    }
}
