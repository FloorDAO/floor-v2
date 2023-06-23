// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {RageQuit} from '@floor/RageQuit.sol';

import {FloorTest} from './utilities/Environments.sol';


contract RageQuitTest is FloorTest {

    /// Set our constant token prices
    uint constant FLOOR_PRICE = 2400000000000000;
    uint constant FUND1_PRICE = 68180900000000000000;  // PUNK
    uint constant FUND2_PRICE = 1000000000000000000;   // WETH

    /// Our funding tokens
    ERC20Mock fundToken1;
    ERC20Mock fundToken2;

    /// Our native Floor token
    FLOOR floor;

    /// Ragequit contract to test against
    RageQuit rageQuit;

    /// Store our test users
    address alice;
    address bob;
    address carol;

    constructor() {
        // Create 2 tokens that will fund our {RageQuit} contract
        fundToken1 = new ERC20Mock();
        fundToken2 = new ERC20Mock();

        // Deploy our {FLOOR} token contract
        floor = new FLOOR(address(authorityRegistry));

        // Deploy our {RageQuit} contract, referencing our FLOOR token
        rageQuit = new RageQuit(address(floor));

        // Set up our test users
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Set our default FLOOR token price for tests
        rageQuit.setFloorValue(FLOOR_PRICE);

        // Deal our ERC20 tokens into our {RageQuit} contract to fund it
        deal(address(fundToken1), address(this), 100 ether);
        deal(address(fundToken2), address(this), 100_000 ether);

        // Approve our tokens to be used by the {RageQuit} contract
        fundToken1.approve(address(rageQuit), 100 ether);
        fundToken2.approve(address(rageQuit), 100_000 ether);

        // Distribute some FLOOR tokens to our test users
        deal(address(floor), alice, 100_000 ether);
        deal(address(floor), bob, 10_000 ether);
        deal(address(floor), carol, 1_000 ether);

        // Approve our {RageQuit} contract to use our test user's floor allocations
        vm.prank(alice);
        floor.approve(address(rageQuit), 100_000 ether);

        vm.prank(bob);
        floor.approve(address(rageQuit), 10_000 ether);

        vm.prank(carol);
        floor.approve(address(rageQuit), 1_000 ether);
    }

    function test_CanSetFloorValue(uint value) public {
        // The token will currently be unknown, so will be 0 value
        assertEq(rageQuit.tokenValue(address(floor)), FLOOR_PRICE);

        // Update our FLOOR token value and confirm that it was updated successfully
        rageQuit.setFloorValue(value);
        assertEq(rageQuit.tokenValue(address(floor)), value);
    }

    function test_CannotSetFloorValueIfNotOwner(uint value) public {
        vm.expectRevert();
        vm.prank(alice);
        rageQuit.setFloorValue(value);
    }

    function test_CanFund() public {
        rageQuit.fund(address(fundToken1), 50 ether, 1);
        rageQuit.fund(address(fundToken2), 50_000 ether, 2);

        assertEq(rageQuit.tokenValue(address(fundToken1)), 1);
        assertEq(rageQuit.tokenValue(address(fundToken2)), 2);

        assertEq(fundToken1.balanceOf(address(rageQuit)), 50 ether);
        assertEq(fundToken2.balanceOf(address(rageQuit)), 50_000 ether);

        rageQuit.fund(address(fundToken1), 50 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 50_000 ether, FUND2_PRICE);

        assertEq(rageQuit.tokenValue(address(fundToken1)), FUND1_PRICE);
        assertEq(rageQuit.tokenValue(address(fundToken2)), FUND2_PRICE);

        assertEq(fundToken1.balanceOf(address(rageQuit)), 100 ether);
        assertEq(fundToken2.balanceOf(address(rageQuit)), 100_000 ether);
    }

    function test_CanRageQuit() public {
        rageQuit.fund(address(fundToken1), 100 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 100_000 ether, FUND2_PRICE);

        assertEq(floor.balanceOf(alice), 100_000 ether);
        assertEq(fundToken1.balanceOf(alice), 0);
        assertEq(fundToken2.balanceOf(alice), 0);

        vm.prank(alice);
        rageQuit.ragequit(10_000 ether);

        assertEq(floor.balanceOf(alice), 90_000 ether);
        assertEq(fundToken1.balanceOf(alice), 176002370165251558);   // 0.1760 PUNK
        assertEq(fundToken2.balanceOf(alice), 12000000000000000000); // 12.000 WETH

        vm.prank(alice);
        rageQuit.ragequit(20_000 ether);

        assertEq(floor.balanceOf(alice), 70_000 ether);
        assertEq(fundToken1.balanceOf(alice), 528007110495754675);   // 0.5280 PUNK
        assertEq(fundToken2.balanceOf(alice), 36000000000000000000); // 36.000 WETH
    }

    function test_CannotRageQuitZeroTokens() public {
        vm.expectRevert();
        vm.prank(alice);
        rageQuit.ragequit(0);
    }

    function test_CannotRageQuitWithInsufficientFloorTokens(uint amount) public {
        vm.assume(amount > 1_000 ether);

        rageQuit.fund(address(fundToken1), 50 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 50_000 ether, FUND2_PRICE);

        vm.expectRevert();
        vm.prank(carol);
        rageQuit.ragequit(amount);
    }

    function test_CannotRageQuitAboveFundHoldings() public {
        rageQuit.fund(address(fundToken1), 50 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 1 ether, FUND2_PRICE);

        vm.expectRevert();
        vm.prank(alice);
        rageQuit.ragequit(1_000 ether);

        rageQuit.pause(true);
        rageQuit.rescue();
        rageQuit.pause(false);

        rageQuit.fund(address(fundToken1), 0 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 50_000 ether, FUND2_PRICE);

        vm.expectRevert();
        vm.prank(alice);
        rageQuit.ragequit(1_000 ether);
    }

    function test_CanPauseRageQuitLogic() public {
        rageQuit.fund(address(fundToken1), 50 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 50_000 ether, FUND2_PRICE);

        rageQuit.pause(true);

        vm.expectRevert();
        vm.prank(alice);
        rageQuit.ragequit(1_000 ether);
    }

    function test_CanRescue() public {
        rageQuit.fund(address(fundToken1), 50 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 50_000 ether, FUND2_PRICE);

        rageQuit.pause(true);

        rageQuit.rescue();

        address[] memory tokens = rageQuit.tokens();
        assertEq(tokens.length, 0);
    }

    function test_CannotRescueWhenNotPaused() public {
        rageQuit.fund(address(fundToken1), 50 ether, FUND1_PRICE);
        rageQuit.fund(address(fundToken2), 50_000 ether, FUND2_PRICE);

        vm.expectRevert();
        rageQuit.rescue();
    }

}
