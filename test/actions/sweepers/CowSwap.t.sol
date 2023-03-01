// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CowSwapSweeper} from '@floor/actions/sweepers/CowSwap.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract CowSwapSweepTest is FloorTest {
    // ..
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ..
    address internal constant SETTLEMENT_CONTRACT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

    // Store our action contract
    CowSwapSweeper action;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Send this address as the {Treasury} parameter so we can see what comes back
        action = new CowSwapSweeper(SETTLEMENT_CONTRACT, WETH, address(this));
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanSweep() public {
        address[] memory collections = new address[](2);
        collections[0] = 0x269616D549D7e8Eaa82DFb17028d0B212D11232A; // PUNK
        collections[1] = 0xAbeA7663c472648d674bd3403D94C858dFeEF728; // PUDGY

        uint[] memory amounts = new uint[](2);
        amounts[0] = 10 ether;
        amounts[1] = 5 ether;

        // Action our trade
        bytes memory orderUid = action.execute{value: 15 ether}(collections, amounts);

        // The action should now be added into the pool, with a UID returned for the
        // order. As we have queried on a specific block, with specific data, we should
        // be able to assert the specific order UID.
        assertEq(
            orderUid, hex'341706193578f583c8ce8f3c715b01a9c044f8fd4eca7dc4f9bb5db184aa9e8482cf76d9b692a66a0dc5f8e0e4b65ca8451a649c6390f4eb'
        );
    }
}
