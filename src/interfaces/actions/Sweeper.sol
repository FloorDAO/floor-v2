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

    /**
     * Specify the {AuthorityControl} permissions, if any, that are required to
     * run the sweeper. If no permissions are set, then anyone can run the sweeper
     * in their allocated sweep window.
     */
    function permissions() public view virtual returns (bytes32);
}

/**
 * Used by mercenary sweepers.
 */
abstract contract IMercenarySweeper {
    function execute(uint warIndex, uint amount) external payable virtual returns (uint);
}
