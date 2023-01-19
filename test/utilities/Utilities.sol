// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {DSTest} from 'ds-test/test.sol';
import {Vm} from 'forge-std/Vm.sol';

/**
 * Common utilities for forge tests.
 *
 * Heavily based on:
 * https://github.com/FrankieIsLost/forge-template/blob/master/src/test/utils/Utilities.sol
 */
contract Utilities is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    bytes32 internal nextUser = keccak256(abi.encodePacked('user address'));

    address public deployer = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

    /**
     * Generates a new user address that we can use.
     */
    function getNextUserAddress() external returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }

    /**
     * Creates a set number of users, giving them an initial fund. We can
     * additionally add user labels if wanted for easier referencing.
     */
    function createUsers(uint userNum, uint initialFunds, string[] memory userLabels)
        public
        returns (address payable[] memory)
    {
        address payable[] memory users = new address payable[](userNum);
        address payable user;

        for (uint i = 0; i < userNum;) {
            // Get the next available address for our user
            user = this.getNextUserAddress();

            // Provide the user with initial funds
            if (initialFunds > 0) {
                vm.deal(user, initialFunds);
            }

            // Add the user to our return array
            users[i] = user;

            // If our index has a user label set, then we can label our
            // newly created address.
            if (userLabels.length > i) {
                vm.label(user, userLabels[i]);
            }

            unchecked {
                ++i;
            }
        }

        return users;
    }

    /**
     * Variation of our createUsers functions that does not require labels.
     */
    function createUsers(uint userNum, uint initialFunds) public returns (address payable[] memory) {
        string[] memory a;
        return createUsers(userNum, initialFunds, a);
    }

    /**
     * Variation of our createUsers functions that does not require labels or
     * an `initialFund`, but instead just defaults to give 100 ether.
     */
    function createUsers(uint userNum) public returns (address payable[] memory) {
        return createUsers(userNum, 100 ether);
    }

    /**
     * Move `block.number` forward by a given number of blocks.
     */
    function mineBlocks(uint numBlocks) external {
        uint targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }

    /**
     * Move `block.timestamp` forward by a given number of seconds.
     */
    function mineTime(uint numSeconds) external {
        // solhint-disable-next-line not-rely-on-time
        uint targetTimestamp = block.timestamp + numSeconds;
        vm.warp(targetTimestamp);
    }
}
