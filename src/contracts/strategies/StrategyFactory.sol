// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {CannotSetNullAddress, CollectionNotApproved, StrategyNotApproved} from '@floor/utils/Errors.sol';

import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {IStrategyRegistry} from '@floor-interfaces/strategies/StrategyRegistry.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

// No empty names, that's just silly
error StrategyNameCannotBeEmpty();

/**
 * Allows for strategies to be created, pairing them with an approved collection. The strategy
 * creation script needs to be as highly optimised as possible to ensure that the gas
 * costs are kept down.
 *
 * This factory will keep an index of created strategies and secondary information to ensure
 * that external applications can display and maintain a list of available strategies.
 */
contract StrategyFactory is AuthorityControl, IStrategyFactory {
    /// Maintains an array of all strategies created
    address[] private _strategies;

    /// Store our Treasury address
    address public treasury;

    /// Contract mappings to our approved collections
    ICollectionRegistry public immutable collectionRegistry;

    /// Contract mappings to our approved strategy implementations
    IStrategyRegistry public immutable strategyRegistry;

    /// Mappings to aide is discoverability
    mapping(uint => address) private _strategyIds;

    /// Mapping of collection to strategy addresses
    mapping(address => address[]) private _collectionStrategies;

    /// Stores a list of bypassed strategies
    mapping(address => bool) private _bypassStrategy;

    /**
     * Store our registries, mapped to their interfaces.
     *
     * @param _authority {AuthorityRegistry} contract address
     * @param _collectionRegistry Address of our {CollectionRegistry}
     */
    constructor(address _authority, address _collectionRegistry, address _strategyRegistry) AuthorityControl(_authority) {
        if (_collectionRegistry == address(0)) revert CannotSetNullAddress();
        if (_strategyRegistry == address(0)) revert CannotSetNullAddress();

        // Type-cast our interfaces and store our registry contracts
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        strategyRegistry = IStrategyRegistry(_strategyRegistry);
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
     * Returns an array of all strategies that belong to a specific collection.
     *
     * @param _collection The address of the collection to query
     *
     * @return address[] Array of strategy addresses
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
        return _strategyIds[_strategyId];
    }

    /**
     * Creates a strategy with an approved collection.
     *
     * @dev The strategy is not created using Clones as there are complications when
     * allocated roles and permissions.
     *
     * @param _name Human-readable name of the strategy
     * @param _strategy The strategy implemented by the strategy
     * @param _strategyInitData Bytes data required by the {Strategy} for initialization
     * @param _collection The address of the collection attached to the strategy
     *
     * @return strategyId_ ID of the newly created strategy
     * @return strategyAddr_ Address of the newly created strategy
     */
    function deployStrategy(bytes32 _name, address _strategy, bytes calldata _strategyInitData, address _collection)
        external
        onlyRole(STRATEGY_MANAGER)
        returns (uint strategyId_, address strategyAddr_)
    {
        // No empty names, that's just silly
        if (_name == '') revert StrategyNameCannotBeEmpty();

        // Make sure the strategy implementation is approved
        if (!strategyRegistry.isApproved(_strategy)) revert StrategyNotApproved(_strategy);

        // Make sure the collection is approved
        if (!collectionRegistry.isApproved(_collection)) revert CollectionNotApproved(_collection);

        // Capture our `strategyId`, before we increment the array length
        strategyId_ = _strategies.length;

        // Deploy a new {Strategy} instance using the clone mechanic
        strategyAddr_ = Clones.cloneDeterministic(_strategy, bytes32(strategyId_));

        // We then need to instantiate the strategy using our supplied `strategyInitData`
        IBaseStrategy(strategyAddr_).initialize(_name, strategyId_, _strategyInitData);

        // Add our strategies to our internal tracking
        _strategies.push(strategyAddr_);

        // Add our mappings for onchain discoverability
        _strategyIds[strategyId_] = strategyAddr_;
        _collectionStrategies[_collection].push(strategyAddr_);

        // Finally we can emit our event to notify watchers of a new strategy
        emit StrategyCreated(strategyId_, strategyAddr_, _collection);
    }

    /**
     * Allows individual strategies to be paused, meaning that assets can no longer be deposited,
     * although staked assets can always be withdrawn.
     *
     * @dev Events are fired within the strategy to allow listeners to update.
     *
     * @param _strategyId strategy ID to be updated
     * @param _paused If the strategy should be paused or unpaused
     */
    function pause(uint _strategyId, bool _paused) public onlyRole(STRATEGY_MANAGER) {
        IBaseStrategy(_strategyIds[_strategyId]).pause(_paused);
    }

    /**
     * Reads the yield generated by all strategies since the last time that this
     * function was called.
     */
    function snapshot(uint _epoch)
        external
        onlyRole(STRATEGY_MANAGER)
        returns (address[] memory strategies_, uint[] memory amounts_, uint totalAmount_)
    {
        // Get our underlying WETH address
        address weth = address(ITreasury(treasury).weth());

        // Prefine some variables
        address[] memory tokens;
        uint[] memory amounts;
        uint tokensLength;

        // Get the number of strategies and define our returned array lengths
        uint strategiesLength = _strategies.length;
        strategies_ = new address[](strategiesLength);
        amounts_ = new uint[](strategiesLength);

        // Iterate over strategies to pull out yield
        for (uint i; i < strategiesLength;) {
            // Prevent a bypassed strategy from snapshotting
            if (!_bypassStrategy[_strategies[i]]) {
                // Snapshot our strategy
                (tokens, amounts) = IBaseStrategy(_strategies[i]).snapshot();

                // Iterate over tokens to just find WETH amounts
                tokensLength = tokens.length;
                for (uint l; l < tokensLength;) {
                    if (tokens[l] == address(weth) && amounts[l] != 0) {
                        strategies_[i] = _strategies[i];
                        amounts_[i] = amounts[l];
                        totalAmount_ += amounts[l];
                    }

                    unchecked { ++l; }
                }
            }

            unchecked { ++i; }
        }

        emit StrategySnapshot(_epoch, strategies_, amounts_);
    }

    /**
     * Harvest available reward yield from the strategy. This won't affect the amount
     * depositted into the contract and should only harvest rewards directly into the
     * {Treasury}.
     *
     * @param _strategyId Strategy ID to be harvested
     */
    function harvest(uint _strategyId) external onlyRole(STRATEGY_MANAGER) {
        if (_bypassStrategy[_strategyIds[_strategyId]]) return;

        IBaseStrategy(_strategyIds[_strategyId]).harvest(treasury);
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
     * @param _strategyId Strategy ID to be withdrawn from
     * @param _data Strategy withdraw function call, using `encodeWithSelector`
     */
    function withdraw(uint _strategyId, bytes calldata _data) external onlyRole(STRATEGY_MANAGER) {
        // If we are bypassing the strategy, then skip this call
        if (_bypassStrategy[_strategyIds[_strategyId]]) return;

        // Extract the selector from data
        bytes4 _selector = bytes4(_data);

        // Create a replication of the bytes data that removes the selector
        bytes memory _newData = new bytes(_data.length - 4);
        for (uint i; i < _data.length - 4; i++) {
            _newData[i] = _data[i + 4];
        }

        // Make a call to our strategy that passes on our withdrawal data
        (bool success,) = _strategyIds[_strategyId].call(
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
    function withdrawPercentage(address _strategy, uint _percentage)
        external
        onlyRole(STRATEGY_MANAGER)
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // Ensure our percentage is valid (less than 100% to 2 decimal places)
        require(_percentage > 0, 'Invalid percentage');
        require(_percentage <= 100_00, 'Invalid percentage');

        // Prevent a bypassed strategy from parsing withdrawal calculations
        if (_bypassStrategy[_strategy]) {
            return (tokens_, amounts_);
        }

        // Calls our strategy to withdraw a percentage of the holdings
        return IBaseStrategy(_strategy).withdrawPercentage(msg.sender, _percentage);
    }

    /**
     * Allow a strategy to be skipped when being processing. This is beneficial if a
     * strategy becomes corrupted at an external point and would otherwise prevent an
     * epoch from ending.
     *
     * @dev This does not shutdown the strategy as it can be undone. If a strategy wants
     * to wind down, then it should also be paused and a full withdraw made.
     */
    function bypassStrategy(address _strategy, bool _bypass) external onlyRole(STRATEGY_MANAGER) {
        _bypassStrategy[_strategy] = _bypass;
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
        if (_treasury == address(0)) revert CannotSetNullAddress();

        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }
}
