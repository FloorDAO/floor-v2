// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import '../../src/contracts/authorities/AuthorityControl.sol';
import '../../src/contracts/authorities/AuthorityRegistry.sol';

import '../utilities/Utilities.sol';


contract FloorTest is Test {

    uint mainnetFork;

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

    modifier forkBlock(uint blockNumber) {
        // Generate a mainnet fork
        mainnetFork = vm.createFork(vm.rpcUrl('mainnet'));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(blockNumber);

        // Confirm that our block number has set successfully
        require(block.number == blockNumber);
        _;
    }

}
