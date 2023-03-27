// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ISweeper {

    function execute(
        address[] calldata collections,
        uint[] calldata amounts,
        bytes calldata data
    ) external payable virtual returns (string memory);

}
