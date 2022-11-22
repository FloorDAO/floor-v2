// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import '../../src/contracts/authorities/AuthorityControl.sol';

import '../utilities/Utilities.sol';


contract FloorTest is Test {

    AuthorityControl authorityControl;
    AuthorityRegistry authorityRegistry;

    Utilities utilities;
    address payable[] users;

    address constant DEPLOYER = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    constructor () {
        // Set up our utilities class
        utilities = new Utilities();

        // Set up a small pool of test users
        users = utilities.createUsers(5, 100 ether);

        // Set up our authority registry
        authorityRegistry = new AuthorityRegistry();

        // Attach our registry control to our control contract
        authorityControl = new AuthorityControl(address(authorityRegistry));
    }

}
