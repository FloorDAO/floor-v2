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
        action = new CowSwapSweeper(SETTLEMENT_CONTRACT, address(this));
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
        string memory orderUid = action.execute{value: 15 ether}(collections, amounts, '');

        // The action(s) should now be added into the pool; but because we generate a UID for
        // each collection sent, we can't assert a specific UID value. So for this reason we
        // just return an empty string as there is no additional content needed. The individual
        // UIDs will be sent as events from the sweep itself.
        assertEq(orderUid, '');
    }
}
