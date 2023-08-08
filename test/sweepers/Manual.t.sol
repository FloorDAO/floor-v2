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
     * Test that any transaction value passed in the sweep is refunded back to the
     * sender. This ensures that if a manual sweeper is used in the Treasury sweep,
     * then all funds will be safely returned.
     */
    function test_EthIsRefundedWhenRegisteringManualSweep(uint amount) public {
        // Assume that our account has enough ETH for gas costs
        vm.assume(amount >= 1 ether);

        // Ensure our test has enough ETH
        deal(address(this), amount);

        // Capture the balance of our user before the sweep call
        uint startBalance = address(this).balance;

        // Execute our sweeper call, sending an amount of ETH
        manualSweeper.execute{value: amount}(collections, amounts, 'test');

        // Capture our closing balance of ETH for the account. This needs to allow
        // for a marginal offset used for gas in the execution. The cost of this
        // execution in gas is not factored into Foundry tests, so we don't
        // accommodate for it.
        assertEq(startBalance, address(this).balance);
    }

    receive () external payable {}

}
