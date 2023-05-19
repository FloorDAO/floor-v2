// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Used by sweepers.
 */
abstract contract ISweeper {
    function execute(address[] calldata collections, uint[] calldata amounts, bytes calldata data)
        external
        payable
        virtual
        returns (string memory);
}

/**
 * Used by mercenary sweepers.
 */
abstract contract IMercenarySweeper {
    function execute(uint warIndex, uint amount) external payable virtual returns (uint);
}
