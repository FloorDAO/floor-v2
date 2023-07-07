// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import {RageQuit} from '@floor/RageQuit.sol';

import {IFLOOR} from '@floor-interfaces/legacy/IFloor.sol';

import {FloorTest} from './utilities/Environments.sol';

contract RageQuitTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_641_210;

    /// Our funding tokens
    ERC20Mock fundToken1;
    ERC20Mock fundToken2;

    /// Our native Floor token
    IFLOOR floor;

    /// Ragequit contract to test against
    RageQuit rageQuit;

    /// Store our test users
    address alice;
    address bob;
    address carol;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Create 2 tokens that will fund our {RageQuit} contract
        fundToken1 = new ERC20Mock();
        fundToken2 = new ERC20Mock();

        // Reference our legacy floor token interface, referencing the current
        // live token on mainnet.
        floor = IFLOOR(0xf59257E961883636290411c11ec5Ae622d19455e);

        // Deploy our {RageQuit} contract, referencing our FLOOR token
        rageQuit = new RageQuit(address(floor));

        // Confirm our token supply determined by our constructor (1,553,278.56304812 tokens)
        assertEq(rageQuit.tokenSupply(address(floor)), 1_553_278_563048120);

        // Set up our test users
        alice = 0x759c6De5bcA9ADE8A1a2719a31553c4B7DE02539;  // 1_350_585
        bob = 0x1695A8ba3f3313f9A9ed075Df09c9fCc60840ba1;    // 3_949
        carol = 0x2cFDCd3a67C3F1Df5a3f33E8001b5c6D345B7Ac2;  // 1_000

        // Deal our ERC20 tokens into our {RageQuit} contract to fund it
        deal(address(fundToken1), address(this), 100 ether);
        deal(address(fundToken2), address(this), 100_000 ether);

        // Approve our tokens to be used by the {RageQuit} contract
        fundToken1.approve(address(rageQuit), 100 ether);
        fundToken2.approve(address(rageQuit), 100_000 ether);

        // Approve our {RageQuit} contract to use our test user's floor allocations
        vm.prank(alice);
        floor.approve(address(rageQuit), type(uint).max);

        vm.prank(bob);
        floor.approve(address(rageQuit), type(uint).max);

        vm.prank(carol);
        floor.approve(address(rageQuit), type(uint).max);
    }

    function test_CanFund() public {
        rageQuit.fund(address(fundToken1), 50 ether);
        rageQuit.fund(address(fundToken2), 50_000 ether);

        assertEq(rageQuit.tokenSupply(address(fundToken1)), 50 ether);
        assertEq(rageQuit.tokenSupply(address(fundToken2)), 50_000 ether);

        assertEq(fundToken1.balanceOf(address(rageQuit)), 50 ether);
        assertEq(fundToken2.balanceOf(address(rageQuit)), 50_000 ether);

        rageQuit.fund(address(fundToken1), 50 ether);
        rageQuit.fund(address(fundToken2), 50_000 ether);

        assertEq(rageQuit.tokenSupply(address(fundToken1)), 100 ether);
        assertEq(rageQuit.tokenSupply(address(fundToken2)), 100_000 ether);

        assertEq(fundToken1.balanceOf(address(rageQuit)), 100 ether);
        assertEq(fundToken2.balanceOf(address(rageQuit)), 100_000 ether);
    }

    function test_CannotFundWhenUnpaused() public {
        rageQuit.unpause();

        vm.expectRevert('Pausable: not paused');
        rageQuit.fund(address(fundToken1), 50 ether);
    }

    function test_CanRageQuit() public {
        rageQuit.fund(address(fundToken1), 100 ether);
        rageQuit.fund(address(fundToken2), 100_000 ether);

        rageQuit.unpause();

        /**
         * Total supply:
         * 1_553_278_563048120
         *
         * Alice holds:
         * 1_350_585_391958528 (86.95%)
         *
         * This means that after burning all of their tokens they should hold
         * 86.95 ether of fund token 1 and 86950 of fund token 2.
         */

        assertEq(floor.balanceOf(alice), 1_350_585_391958528);
        assertEq(fundToken1.balanceOf(alice), 0);
        assertEq(fundToken2.balanceOf(alice), 0);

        vm.prank(alice);
        rageQuit.ragequit(1_000_000_000000000);

        assertEq(floor.balanceOf(alice), 350_585_391958528);
        assertEq(fundToken1.balanceOf(alice), 64_379952430272506560);
        assertEq(fundToken2.balanceOf(alice), 64379_952430272506560727);

        vm.prank(alice);
        rageQuit.ragequit(350_585_391958528);

        assertEq(floor.balanceOf(alice), 0);
        assertEq(fundToken1.balanceOf(alice), 86_950623287310980552);
        assertEq(fundToken2.balanceOf(alice), 86950_623287310980552954);

        vm.prank(bob);
        rageQuit.ragequit(3_949_861333627);

        assertEq(floor.balanceOf(bob), 0);
        assertEq(fundToken1.balanceOf(bob), 254291884765078982);
        assertEq(fundToken2.balanceOf(bob), 254_291884765078982490);

        vm.prank(carol);
        rageQuit.ragequit(1_000_000000000);

        assertEq(floor.balanceOf(carol), 0);
        assertEq(fundToken1.balanceOf(carol), 64379952430272506);
        assertEq(fundToken2.balanceOf(carol), 64_379952430272506560);
    }

    function test_CannotRageQuitZeroTokens() public {
        rageQuit.unpause();

        vm.expectRevert();
        vm.prank(alice);
        rageQuit.ragequit(0);
    }

    function test_CannotRageQuitWithInsufficientFloorTokens(uint amount) public {
        vm.assume(amount > 1_000 ether);

        rageQuit.fund(address(fundToken1), 50 ether);
        rageQuit.fund(address(fundToken2), 50_000 ether);

        rageQuit.unpause();

        vm.expectRevert('ERC20: burn amount exceeds balance');
        vm.prank(carol);
        rageQuit.ragequit(amount);
    }

    function test_CannotRageQuitWhenPaused() public {
        rageQuit.fund(address(fundToken1), 50 ether);
        rageQuit.fund(address(fundToken2), 50_000 ether);

        vm.expectRevert();
        vm.prank(alice);
        rageQuit.ragequit(1_000 ether);
    }

    function test_CanRescue() public {
        rageQuit.fund(address(fundToken1), 50 ether);
        rageQuit.fund(address(fundToken2), 50_000 ether);

        rageQuit.rescue();

        address[] memory tokens = rageQuit.tokens();
        assertEq(tokens.length, 0);
    }

    function test_CannotRescueWhenNotPaused() public {
        rageQuit.fund(address(fundToken1), 50 ether);
        rageQuit.fund(address(fundToken2), 50_000 ether);

        rageQuit.unpause();

        vm.expectRevert('Pausable: not paused');
        rageQuit.rescue();
    }

    modifier unpaused {
        rageQuit.unpause();
        _;
    }
}
