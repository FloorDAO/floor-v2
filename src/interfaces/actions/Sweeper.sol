// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ISweeper {
    function execute(address[] calldata collections, uint[] calldata amounts) external payable virtual returns (bytes memory);
}
