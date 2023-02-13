// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ISweeper {

    function execute(address[] memory collections, uint[] memory amounts) external virtual payable returns (bytes memory);

}
