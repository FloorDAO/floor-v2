// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ManualSweeper} from '@floor/sweepers/Manual.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract ManualSweeperTest is FloorTest {

    /// Define our sweeper that we will be testing
    ManualSweeper manualSweeper;

    /// Define some empty arrays for the sweep data, as we won't require
    /// these to test anything with.
    address[] collections;
    uint[] amounts;

    constructor() {
        // Deploy our sweeper
        manualSweeper = new ManualSweeper();
    }

    /**
     * Test that we can pass a string to a sweep execution and retrieve it in the response. We
     * also check that the balance of the caller has not been reduced, even though we are not
     * sending any `msg.value` with the call.
     */
    function test_CanRegisterManualSweepWithTx() public {
        // Capture our starting balance
        uint balance = address(this).balance;

        // Send our sweep request with a test transaction message in the bytes data
        string memory message = manualSweeper.execute(collections, amounts, 'test');

        // Confirm that we receive the same message back
        assertEq(message, 'test');

        // Ensure that our balance remains the same
        assertEq(address(this).balance, balance);
    }

    /**
     * Test that we cannot pass an empty string to the sweeper, as this would provide
     * no context and the sweep would be moot.
     */
    function test_CannotRegisterManualSweepWithEmptyString() public {
        // We should not be able to make a successful call without a string value
        vm.expectRevert('Invalid data parameter');
        manualSweeper.execute(collections, amounts, '');
    }

    /**
     * Test that we cannot pass any transaction value in the sweep execution. We do not
     * have any access to any ETH or tokens that are passed into the contract, so we shouldn't
     * be able to send any that would essentially lock it / burn it.
     */
    function test_CannotSendEthWhenRegisteringManualSweep(uint amount) public {
        // Only test with values above zero
        vm.assume(amount > 0);

        // Ensure our test has enough ETH
        deal(address(this), amount);

        // When calling with a `msg.value`, we expect it to revert
        vm.expectRevert('ETH should not be sent in call');
        manualSweeper.execute{value: amount}(collections, amounts, 'test');
    }

}
