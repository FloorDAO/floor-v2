// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IMercenarySweeper} from '@floor-interfaces/actions/Sweeper.sol';

import {ERC721Mock} from './erc/ERC721Mock.sol';

/**
 * Runs a mocked sweep and mints tokens to the {Treasury}. This makes the assumption that
 * any amount purchased will be available and that each token will be listed for 1 ETH.
 */
contract MercenarySweeperMock is IMercenarySweeper {
    /// Stores a {Treasury} address that will be the recipient of tokens
    address internal treasury;

    /// Stores the {ERC721Mock} that we will mint from this contract to the {Treasury}
    ERC721Mock erc721;

    /**
     * Sets our {Treasury} address for the contract.
     *
     * @param _treasury The {Treasury} address
     */
    constructor (address _treasury, address _erc721) {
        erc721 = ERC721Mock(_erc721);
        treasury = _treasury;
    }

    /**
     * `Deal`s each of the specific collections with their relative amounts to the `treasury`
     * address stored in the contract. It will then return the string message.
     */
    function execute(uint /* warIndex */, uint amount) external payable override returns (uint spend) {
        // Ensure the caller is the treasury
        require(msg.sender == treasury, 'Invalid caller');

        // Mint an amount of ERC721 tokens to the {Treasury}. These will have IDs corresponding
        // to the amount (e.g. an amount of 3 will mint tokens 1, 2 and 3).
        for (uint i = 1; i <= amount; i++) {
            erc721.mint(treasury, i);
        }

        // Find any remaining after spend and send it back to the caller
        spend = amount * 1 ether;
        uint endBalance = address(this).balance - spend;

        if (endBalance != 0) {
            (bool success,) = address(msg.sender).call{value: endBalance}('');
            require(success);
        }
    }
}
