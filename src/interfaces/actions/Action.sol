// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAction {
    function execute(bytes calldata) external returns (uint);
}
