// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {RawTx} from '@floor/actions/utils/RawTx.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract RawTxTest is FloorTest {
    /// Store our action contract
    RawTx action;

    /// Test contract to hit raw
    ExternalContractPayable payableContract;
    ExternalContractNotPayable notPayableContract;

    /// Emitted when an action is processed, including relevant information.
    event ActionEvent(string indexed logName, bytes data);

    constructor() {
        // Set up a RawTx action
        action = new RawTx();

        // Set up a test contract that we will be hitting
        payableContract = new ExternalContractPayable();
        notPayableContract = new ExternalContractNotPayable();
    }

    /**
     * Confirm that we can call a raw transaction to a payable contract.
     */
    function test_CanCallRawTxPayableContract() external {
        // Build our request
        bytes memory request = abi.encode(
            address(payableContract),
            abi.encodeWithSelector(ExternalContractPayable.executeFree.selector, abi.encode(10, 5))
        );

        // Expect our event to be emitted
        vm.expectEmit(true, true, false, true, address(action));
        emit ActionEvent('UtilsRawTx', request);

        // Execute our action
        action.execute(request);
    }

    function test_CanCallRawTxNonPayableContract() external {
        // Build our request
        bytes memory request = abi.encode(
            address(notPayableContract),
            abi.encodeWithSelector(ExternalContractNotPayable.executeFree.selector, abi.encode(10))
        );

        // Expect our event to be emitted
        vm.expectEmit(true, true, false, true, address(action));
        emit ActionEvent('UtilsRawTx', request);

        // Execute our action
        action.execute(request);
    }

    function test_CanCallRawTxWithMsgValue(uint amount) external {
        // Ensure our amount is above the requirement, but below holding
        vm.assume(amount >= 1 ether);
        vm.assume(amount <= address(this).balance);

        // Build our request
        bytes memory request = abi.encode(
            address(payableContract),
            abi.encodeWithSelector(ExternalContractPayable.executeMsgValue.selector, abi.encode(10, 5))
        );

        // Expect our event to be emitted
        vm.expectEmit(true, true, false, true, address(action));
        emit ActionEvent('UtilsRawTx', request);

        // Execute our action
        action.execute{value: amount}(request);
    }

    function test_CanReceiveRefundFromCall(uint amount) external {
        // Ensure our amount is above the requirement, but below holding. In this test, we
        // also want to make the test amount an even number so that it is simpler to test.
        vm.assume(amount >= 1 ether);
        vm.assume(amount <= address(this).balance);
        vm.assume(amount % 2 == 0);

        // Capture our start balance
        uint startBalance = address(this).balance;

        // Build our request
        bytes memory request = abi.encode(
            address(payableContract),
            abi.encodeWithSelector(ExternalContractPayable.executeMsgValue.selector, abi.encode(10, 5))
        );

        // Expect our event to be emitted
        vm.expectEmit(true, true, false, true, address(action));
        emit ActionEvent('UtilsRawTx', request);

        // Execute our action
        action.execute{value: amount}(request);

        // Confirm that we have the expected remaining balance
        assertEq(address(this).balance, startBalance - (amount / 2));
    }

    function test_CanRevertWhenTargetRevertsCall() external {
        // Build an invalid request
        bytes memory request = abi.encode(
            address(notPayableContract),
            abi.encodeWithSelector(ExternalContractPayable.executeFree.selector, abi.encode(10, 5))
        );

        // Execute our action
        vm.expectRevert('Transaction failed');
        action.execute(request);
    }

    receive() external payable {}
}

contract ExternalContractPayable {

    function executeFree(uint inputOne, uint inputTwo) public pure returns (uint) {
        return inputOne + inputTwo - 1;
    }

    function executeMsgValue() public payable returns (uint) {
        // Ensure we have been sent at least 1 ether
        require(msg.value >= 1 ether);

        // Return half of the value sent
        bool sent = payable(msg.sender).send(msg.value / 2);
        require(sent, 'Failed to return eth');

        return msg.value / 2;
    }

    receive() external payable {}
}

contract ExternalContractNotPayable {

    function executeFree(uint input) public pure returns (uint) {
        return input - 1;
    }

}
