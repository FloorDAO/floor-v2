// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {GemSweep} from '@floor/actions/gem/Sweep.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract GemSweepTest is FloorTest {
    /**
     * Prior to this test, I generated some API transaction code via the Gem.xyz API
     * that provided the following target and data parameters. These were generated at
     * our specified block number, so they should be available to sweep.
     */

    address TARGET = 0x1f1606FEeE5b2AFD1e34C5F09B44A8208D6aEECC;
    bytes DATA =
        hex'6d8b99f700000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000022c5b4041d2442ae0000000000000000000000001b3cb81e51011b549d78bf720b0d924ac763a7c200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000031c0000000000000000000000000000000000000000000000000000000000000414200000000000000000000000000000000000000000000000000000000000041fb000000000000000000000000000000000000000000000000000000000000483500000000000000000000000000000000000000000000000000000000000053ac72db8c0b';

    // Store our lil pudgy contract address we will be testing with
    address internal constant LILS_CONTRACT = 0x524cAB2ec69124574082676e6F654a18df49A048;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    // Store our action contract
    GemSweep action;

    /**
     * Sets up our mainnet fork.
     */
    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        action = new GemSweep();
    }

    function test_CannotSetGemSwapWithoutPermissions() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(users[0]);
        action.setGemSwap(TARGET);
    }

    function test_CanSweep() external {
        // Set our GemSwap contract
        action.setGemSwap(TARGET);

        // Execute our sweep
        // Generated transaction should cost `2_505606697463333550`, but we send an
        // additional amount to confirm that we receive refund of remaining ETH.
        action.execute{value: 5 ether}(DATA);

        // The recipient of the action sweep transaction is: `0x1b3cB81E51011b549d78bf720b0d924ac763A7C2`
        assertEq(ERC721(LILS_CONTRACT).ownerOf(12736), 0x1b3cB81E51011b549d78bf720b0d924ac763A7C2);
        assertEq(ERC721(LILS_CONTRACT).ownerOf(16706), 0x1b3cB81E51011b549d78bf720b0d924ac763A7C2);
        assertEq(ERC721(LILS_CONTRACT).ownerOf(16891), 0x1b3cB81E51011b549d78bf720b0d924ac763A7C2);
        assertEq(ERC721(LILS_CONTRACT).ownerOf(18485), 0x1b3cB81E51011b549d78bf720b0d924ac763A7C2);
        assertEq(ERC721(LILS_CONTRACT).ownerOf(21420), 0x1b3cB81E51011b549d78bf720b0d924ac763A7C2);
    }

    receive() external payable {
        // We need to assert that we receive the correct refund amount as expected from the
        // `test_CanSweep` call.
        assertEq(msg.value, 2494393302536676450);
    }
}
