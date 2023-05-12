// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {CollectionNotApproved} from '@floor/utils/Errors.sol';

import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';


// No empty names, that's just silly
error StrategyNameCannotBeEmpty();


/**
 * Allows for vaults to be created, pairing them with an approved collection. The vault
 * creation script needs to be as highly optimised as possible to ensure that the gas
 * costs are kept down.
 *
 * This factory will keep an index of created vaults and secondary information to ensure
 * that external applications can display and maintain a list of available vaults.
 */
contract StrategyFactory is AuthorityControl, IStrategyFactory {
    /// Maintains an array of all vaults created
    address[] private _strategies;

    /// Store our Treasury address
    address public treasury;

    /// Contract mappings to our internal registries
    ICollectionRegistry public immutable collectionRegistry;

    /// Mappings to aide is discoverability
    mapping(uint => address) private strategyIds;
    mapping(address => address[]) public collectionStrategies;

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
     * Provides a list of all strategies created.
     *
     * @return Array of all strategies created by the {StrategyFactory}
     */
    function strategies() external view returns (address[] memory) {
        return _strategies;
    }

    /**
     * Provides a strategy against the provided `strategyId` (index). If the index does not exist,
     * then address(0) will be returned.
     *
     * @param _strategyId ID of the strategy to retrieve
     *
     * @return Address of the strategy
     */
    function strategy(uint _strategyId) external view returns (address) {
        return strategyIds[_strategyId];
    }

    /**
     * Creates a vault with an approved collection.
     *
     * @dev The vault is not created using Clones as there are complications when allocated
     * roles and permissions.
     *
     * @param _name Human-readable name of the vault
     * @param _strategy The strategy implemented by the vault
     * @param _strategyInitData Bytes data required by the {Strategy} for initialization
     * @param _collection The address of the collection attached to the vault
     *
     * @return strategyId_ ID of the newly created vault
     * @return strategyAddr_ Address of the newly created vault
     */
    function deployStrategy(
        bytes32 _name,
        address _strategy,
        bytes calldata _strategyInitData,
        address _collection
    ) external onlyRole(VAULT_MANAGER) returns (uint strategyId_, address strategyAddr_) {
        // No empty names, that's just silly
        if (_name == '') {
            revert StrategyNameCannotBeEmpty();
        }

        // Make sure the collection is approved
        if (!collectionRegistry.isApproved(_collection)) {
            revert CollectionNotApproved(_collection);
        }

        // Capture our vaultId, before we increment the array length
        strategyId_ = _strategies.length;

        // Deploy a new {Strategy} instance using the clone mechanic
        strategyAddr_ = Clones.cloneDeterministic(_strategy, bytes32(strategyId_));

        // We then need to instantiate the strategy using our supplied `strategyInitData`
        IBaseStrategy(strategyAddr_).initialize(_name, strategyId_, _strategyInitData);

        // Add our vaults to our internal tracking
        _strategies.push(strategyAddr_);

        // Add our mappings for onchain discoverability
        strategyIds[strategyId_] = strategyAddr_;
        collectionStrategies[_collection].push(strategyAddr_);

        // Finally we can emit our event to notify watchers of a new vault
        emit VaultCreated(strategyId_, strategyAddr_, _collection);
    }

    /**
     * Allows individual vaults to be paused, meaning that assets can no longer be deposited,
     * although staked assets can always be withdrawn.
     *
     * @dev Events are fired within the vault to allow listeners to update.
     *
     * @param _strategyId Vault ID to be updated
     * @param _paused If the vault should be paused or unpaused
     */
    function pause(uint _strategyId, bool _paused) public onlyRole(VAULT_MANAGER) {
        IBaseStrategy(strategyIds[_strategyId]).pause(_paused);
    }

    /**
     * TODO: ..
     */
    function snapshot(uint _strategyId) external /* TODO: onlyRole */ returns (address[] memory tokens, uint[] memory amounts) {

    }

    /**
     * TODO: ..
     */
    function harvest(uint _strategyId) external /* TODO: onlyRole */ {
        IBaseStrategy(strategyIds[_strategyId]).harvest(treasury);
    }

    /**
     * TODO: ..
     */
    function withdraw(uint _strategyId, bytes calldata _data) external /* TODO: onlyRole */ {
        // Extract the selector from data
        bytes4 _selector = bytes4(_data);

        // Create a replication of the bytes data that removes the selector
        bytes memory _newData = new bytes(_data.length - 4);
        for (uint i; i < _data.length - 4; i++) {
            _newData[i] = _data[i + 4];
        }

        // Make a call to our strategy that passes on our withdrawal data
        (bool success,) = strategyIds[_strategyId].call(
            // Sandwich the selector against the recipient and remaining data
            abi.encodePacked(
                abi.encodeWithSelector(_selector, treasury),
                _newData
            )
        );

        // If our call failed, return a standardised message rather than decoding
        require(success, 'Unable to withdraw');
    }

    /**
     * ..
     */
    function setTreasury(address _treasury) public onlyRole(TREASURY_MANAGER) {
        treasury = _treasury;
    }

}
