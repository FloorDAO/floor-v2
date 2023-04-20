// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CowSwapCreateOrder} from '@floor/actions/cowswap/CreateOrder.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract CowSwapCreateOrderTest is FloorTest {
    // ..
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ..
    address internal constant SETTLEMENT_CONTRACT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

    address alice;

    // Store our action contract
    CowSwapCreateOrder action;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Send this address as the {Treasury} parameter so we can see what comes back
        action = new CowSwapCreateOrder(SETTLEMENT_CONTRACT);

        alice = users[0];
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanSweep() public {
        address PUDGY = 0xAbeA7663c472648d674bd3403D94C858dFeEF728;

        // Action our trade
        action.execute{value: 30 ether}(
            abi.encode(
                WETH,     // address sellToken;
                PUDGY,    // address buyToken;
                alice,    // address receiver;
                20 ether, // uint256 sellAmount;
                20 ether, // uint256 buyAmount;
                1 ether   // uint256 feeAmount;
            )
        );

        // The action(s) should now be added into the pool. The UID that is generated will be
        // sent as an event.
        // TODO: Check the event
    }

    /**
     * ..
     */
    receive() external payable {
        assertEq(msg.value, 999880756991001119);
    }

}
