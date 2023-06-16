// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/console.sol";

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

    /// Mapping of collection to strategy addresses
    mapping(address => address[]) internal _collectionStrategies;

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
     *
     */
    function collectionStrategies(address _collection) external view returns (address[] memory) {
        return _collectionStrategies[_collection];
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
    function deployStrategy(bytes32 _name, address _strategy, bytes calldata _strategyInitData, address _collection)
        external
        onlyRole(VAULT_MANAGER)
        returns (uint strategyId_, address strategyAddr_)
    {
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
        _collectionStrategies[_collection].push(strategyAddr_);

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
     * Reads the yield generated by a strategy since the last time that this function was called.
     *
     * @param _strategyId Vault ID to be updated
     *
     * @return tokens Tokens that have been generated as yield
     * @return amounts The amount of yield generated for the corresponding token
     */
    function snapshot(uint _strategyId) external onlyRole(VAULT_MANAGER) returns (address[] memory tokens, uint[] memory amounts) {
        (tokens, amounts) = IBaseStrategy(strategyIds[_strategyId]).snapshot();
        emit StrategySnapshot(_strategyId, tokens, amounts);
    }

    /**
     * Harvest available reward yield from the strategy. This won't affect the amount
     * depositted into the contract and should only harvest rewards directly into the
     * {Treasury}.
     *
     * @param _strategyId Vault ID to be updated
     */
    function harvest(uint _strategyId) external onlyRole(VAULT_MANAGER) {
        IBaseStrategy(strategyIds[_strategyId]).harvest(treasury);
    }

    /**
     * Makes a call to a strategy withdraw function by passing the strategy ID and
     * `abi.encodeWithSelector` to build the bytes `_data` parameter. This will then
     * pass the data on to the strategy function and inject the treasury recipient
     * address within the call as the first function parameter.
     *
     * @dev It is required for the transaction to return a successful call, otherwise
     * the transaction will be reverted. The error response will be standardised so
     * debugging will require a trace, rather than just the end message.
     *
     * @param _strategyId Vault ID to be updated
     * @param _data Strategy withdraw function call, using `encodeWithSelector`
     */
    function withdraw(uint _strategyId, bytes calldata _data) external onlyRole(VAULT_MANAGER) {
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
            abi.encodePacked(abi.encodeWithSelector(_selector, treasury), _newData)
        );

        // If our call failed, return a standardised message rather than decoding
        require(success, 'Unable to withdraw');
    }

    /**
     * Makes a call to a strategy withdraw function.
     *
     * @param _strategy Strategy address to be updated
     * @param _percentage The percentage of position to withdraw from
     */
    function withdrawPercentage(address _strategy, uint _percentage) external onlyRole(VAULT_MANAGER) returns (address[] memory, uint[] memory) {
        console.log('111');
        // Ensure our percentage is valid (less than 100% to 2 decimal places)
        require(_percentage > 0, 'Invalid percentage');
        console.log('222');
        require(_percentage <= 10000, 'Invalid percentage');
        console.log('333');

        // Calls our strategy to withdraw a percentage of the holdings
        return IBaseStrategy(_strategy).withdrawPercentage(msg.sender, _percentage);
    }

    /**
     * Allows the {Treasury} contract address to be updated. All withdrawals will
     * be requested to be sent to this address when the `withdraw` is called.
     *
     * @dev This address is dynamically injected into the subsequent strategy
     * withdraw call.
     *
     * @param _treasury The new {Treasury} contract address
     */
    function setTreasury(address _treasury) public onlyRole(TREASURY_MANAGER) {
        treasury = _treasury;
    }
}
