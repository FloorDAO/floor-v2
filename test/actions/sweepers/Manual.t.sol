// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ManualSweeper} from '@floor/sweepers/Manual.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract ManualSweepTest is FloorTest {

    // Store our action contract
    ManualSweeper action;

    constructor() {
        // Send this address as the {Treasury} parameter so we can see what comes back
        action = new ManualSweeper();
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanSweep() public {
        // Action our trade
        string memory message = action.execute{value: 15 ether}(
            new address[](0),
            new uint[](0),
            'Swept at: 0x74827d6490ce3235ae0da41418e5a9b399158960a079ab2ae1e47e1802f4437e'
        );

        // The action will just return a message that we have sent, as this will be logged
        // by the {Treasury} against the sweep.
        assertEq(message, 'Swept at: 0x74827d6490ce3235ae0da41418e5a9b399158960a079ab2ae1e47e1802f4437e');
    }
}
