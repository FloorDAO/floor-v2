// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SendEth} from '../../../src/contracts/actions/utils/SendEth.sol';

import '../../utilities/Environments.sol';

contract SendEthTest is FloorTest {

    // Store our action contract
    SendEth action;

    constructor() {
        // Set up a SendEth action
        action = new SendEth();
    }

    function test_CanSendEth(uint amount) external {
        // Ensure that our fuzz amount is always less that the balance of our test account
        vm.assume(amount <= address(this).balance);

        // Get the starting balance of the sender and recipient
        uint startBalance = address(this).balance;
        uint recipientStartBalance = users[1].balance;

        // Execute our action
        action.execute{value: amount}(abi.encode(users[1], amount));

        assertEq(address(this).balance, startBalance - amount);
        assertEq(users[1].balance, recipientStartBalance + amount);
    }

    function test_CannotSendEthToNonPayableRecipient(uint amount) external {
        // Ensure that our fuzz amount is above the balance held
        vm.assume(amount > address(this).balance);

        // Execute our action
        vm.expectRevert();
        action.execute{value: amount}(abi.encode(users[1], amount));
    }

    function test_CannotSendEthWithoutEnoughValue(uint amount) external {
        // Ensure that our fuzz amount is more than 1, as we subtract that from what's sent
        vm.assume(amount != 0);

        // Execute our action
        vm.expectRevert();
        action.execute{value: amount - 1}(abi.encode(users[1], amount));
    }

    function test_CanGetDustReturnedToSender() external {
        // Get the starting balance of the sender and recipient
        uint startBalance = address(this).balance;
        uint recipientStartBalance = users[1].balance;

        // Execute our action
        action.execute{value: 10 ether}(abi.encode(users[1], 5 ether));

        assertEq(address(this).balance, startBalance - 10 ether + 5 ether);
        assertEq(users[1].balance, recipientStartBalance + 5 ether);
    }

    receive() external payable {
        // Assertion of our gas refund from `test_CanGetDustReturnedToSender`
        assertEq(msg.value, 5 ether);
    }

}
