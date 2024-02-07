// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';
import {Treasury} from '@floor/Treasury.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';


/**
 * Allows any collection address to be mapped onto another ISweeper contract. This allows
 * for different collection types to be swept within the same sweep.
 *
 * @dev If all collections are going to use the same sweeper approach, then this contract
 * should not be used as it will only inflate gas.
 */
contract SweeperRouter is ISweeper, Ownable {

    /// Define a structure that holds sweep triggering information.
    struct CollectionSweeper {
        ISweeper sweeper;
        bytes data;
    }

    /// An event fired when a collection sweeper is updated
    event CollectionSweeperUpdated(address _collection, address _sweeper, bytes _data);

    /// A mapping that correlates a collection address to a sweeper
    mapping (address => CollectionSweeper) public collectionSweepers;

    /// Stores our {Treasury} contract to reference approved sweepers
    Treasury treasury;

    /**
     * ..
     */
    constructor (address payable _treasury) {
        // Ensure we are not setting {Treasury} to a zero address
        if (_treasury == address(0)) revert CannotSetNullAddress();

        // Register our {Treasury} address
        treasury = Treasury(_treasury);
    }

    /**
     * ..
     */
    function execute(
        address[] calldata _collections,
        uint[] calldata _amounts,
        bytes calldata /* data */
    ) external payable override returns (string memory) {
        // Create variables outside of our loop. Each individual sweeper expects an array of values,
        // so we need to create a single-element array for each.
        CollectionSweeper memory collectionSweeper;
        address[] memory collection = new address[](1);
        uint[] memory amount = new uint[](1);

        // Iterate over our collections to execute each ones specific sweeper
        uint collectionsLength = _collections.length;
        for (uint i; i < collectionsLength;) {
            // Set up the collection sweeper parameters
            collectionSweeper = collectionSweepers[_collections[i]];

            // Confirm that the sweeper is approved
            require(treasury.approvedSweepers(address(collectionSweeper.sweeper)), 'Sweeper contract not approved');

            // Convert our single values into the expected array value
            collection[0] = _collections[i];
            amount[0] = _amounts[i];

            // Trigger the collection sweeper, sending the specific amount of ETH
            collectionSweeper.sweeper.execute{value: _amounts[i]}(collection, amount, collectionSweeper.data);

            unchecked { ++i; }
        }

        return '';
    }

    /**
     * Allows a new
     */
    function setSweeper(address _collection, address _sweeper, bytes calldata _data) public onlyOwner {
        // Set the sweeper against the collection
        collectionSweepers[_collection] = CollectionSweeper({
            sweeper: ISweeper(_sweeper),
            data: _data
        });

        // Tell our stalkers about our new collection sweeper
        emit CollectionSweeperUpdated(_collection, _sweeper, _data);
    }

    /**
     * Specify that anyone can run this sweeper.
     */
    function permissions() public pure override returns (bytes32) {
        return '';
    }

    /**
     * Allow the contract to receive ETH back during the `endSweep` call.
     */
    receive() external payable {}
}
