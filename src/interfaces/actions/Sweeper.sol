// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ISweeper {
    function execute(address[] memory collections, uint[] memory amounts) external payable virtual returns (bytes memory);
}
