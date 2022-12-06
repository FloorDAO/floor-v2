// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


abstract contract BaseAction {

    struct ActionRequest {}
    struct ActionResponse {}

    function execute(ActionRequest request) public returns (ActionResponse response) {}
    function handles(address[]) {}

    function deposit() {}
    function withdraw() {}

}
