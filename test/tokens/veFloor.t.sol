// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../src/contracts/tokens/VeFloor.sol';

import '../utilities/Environments.sol';


contract VeFloorTokenTest is FloorTest {

    // Store some test users
    address alice;
    address bob;

    // Reference our veFloor token contract
    veFLOOR veFloor;

    constructor () {
        // Deploy our veFLOOR token contract
        veFloor = new veFLOOR('veFloor', 'veFLOOR', address(authorityRegistry));

        // Set up our user references
        (alice, bob) = (users[0], users[1]);
    }

    /**
     * Our veFloor should only be able to be minted by addresses that have the `FLOOR_MANAGER`
     * role, so we need to ensure that they are able to call with any positive uint amount to
     * be minted and that it succeeds in sending to the recipient.
     */
    function test_CanMintWithRole(uint amount) public {
        // Confirm we can't mint directly
        vm.expectRevert('Account does not have role');
        vm.prank(bob);
        veFloor.mint(bob, amount);

        assertEq(veFloor.balanceOf(bob), 0);

        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(bob));

        vm.prank(bob);
        veFloor.mint(bob, amount);

        assertEq(veFloor.balanceOf(bob), amount);
    }

    /**
     * Holders of veFloor should be able to burn their tokens.
     */
    function test_CanBurn(uint mintAmount, uint burnAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(burnAmount > 0);
        vm.assume(mintAmount > burnAmount);

        assertEq(veFloor.balanceOf(address(this)), 0);

        veFloor.mint(address(this), mintAmount);
        assertEq(veFloor.balanceOf(address(this)), mintAmount);

        veFloor.burnFrom(address(this), burnAmount);
        assertEq(veFloor.balanceOf(address(this)), mintAmount - burnAmount);
    }

}
