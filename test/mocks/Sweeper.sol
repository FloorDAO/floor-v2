// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

import {FloorTest} from '../utilities/Environments.sol';

/**
 * Runs a mocked sweep and `deal`s tokens to the {Treasury}. This makes the assumption that
 * each token purchased is returned at "1 ether in 18 decimals" per WETH.
 */
contract SweeperMock is FloorTest, ISweeper {
    /// Stores a {Treasury} address that will be the recipient of tokens
    address internal treasury;

    /**
     * Sets our {Treasury} address for the contract.
     *
     * @param _treasury The {Treasury} address
     */
    constructor (address _treasury) {
        treasury = _treasury;
    }

    /**
     * `Deal`s each of the specific collections with their relative amounts to the `treasury`
     * address stored in the contract. It will then return the string message.
     */
    function execute(address[] calldata collections, uint[] calldata amounts, bytes calldata data)
        external
        payable
        override
        returns (string memory)
    {
        // Ensure the caller is the treasury
        require(msg.sender == treasury, 'Invalid caller');

        // Iterate over our collections and `deal` the amounts to the `treasury`
        for (uint i; i < collections.length; ++i) {
            deal(collections[i], treasury, IERC20(collections[i]).balanceOf(treasury) + amounts[i]);
        }

        // Return the bytes data that was provided as a string
        return string(data);
    }

    /**
     * In our test suites, allow all permissions.
     */
    function permissions() public pure override returns (bytes32) {
        return '';
    }

    receive () payable external {}
}
