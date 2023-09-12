// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Action} from '@floor/actions/Action.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract ActionTest is Action, FloorTest {

    constructor() {
        emit log_address(DEFAULT_SENDER);
    }

    function test_CanExecuteWithOptionalValue(uint _data, uint _value) external {
        // Ensure our amount is below holding
        vm.assume(_value <= address(this).balance);

        uint response = this.execute{value: _value}(abi.encode(_data));
        assertEq(response, _data);
    }

    function test_CannotExecuteWhenPaused(uint _data, uint _value) external {
        // Ensure our amount is below holding
        vm.assume(_value <= address(this).balance);

        vm.prank(DEFAULT_SENDER);
        this.pause(true);

        vm.expectRevert('Pausable: paused');
        this.execute{value: _value}(abi.encode(_data));

        vm.prank(DEFAULT_SENDER);
        this.pause(false);

        uint response = this.execute{value: _value}(abi.encode(_data));
        assertEq(response, _data);
    }

    function test_CanPauseAndUnpause() external {
        vm.startPrank(DEFAULT_SENDER);

        assertFalse(this.paused());

        this.pause(true);
        assertTrue(this.paused());

        vm.expectRevert('Pausable: paused');
        this.pause(true);

        this.pause(false);
        assertFalse(this.paused());

        vm.expectRevert('Pausable: not paused');
        this.pause(false);

        vm.stopPrank();
    }

    function test_CannotPauseOrUnpauseWithoutPermissions() external {
        vm.prank(users[1]);
        vm.expectRevert('Ownable: caller is not the owner');
        this.pause(true);
    }

    /* === */

    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        return abi.decode(_request, (uint));
    }

    receive() external payable {}
}


