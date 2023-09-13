// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {VestingClaim} from '@floor/migrations/VestingClaim.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';

import {ERC20Mock} from '../mocks/erc/ERC20Mock.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract VestingClaimTest is FloorTest {
    // Store some test tokens
    FLOOR newFloor;
    ERC20Mock weth;

    // Store our contract to test
    VestingClaim vestingClaim;

    // Store our test users
    address alice;
    address bob;
    address carol;
    address david;
    address treasury;

    // Set a starting WETH balance
    uint internal constant startBalance = 10 ether;
    uint internal constant claimCost = 0.001 ether;

    constructor() {
        // Set up our migration contract
        newFloor = new FLOOR(address(authorityRegistry));
        weth = new ERC20Mock();

        // Set up a small number of users to test
        (alice, bob, carol, david, treasury) = (users[0], users[1], users[2], users[3], users[4]);

        // Set up a floor vesting claim contract
        vestingClaim = new VestingClaim(address(newFloor), address(weth), treasury);

        // Give Alice sufficient WETH
        weth.mint(alice, startBalance);
        vm.prank(alice);
        weth.approve(address(vestingClaim), startBalance);

        // Grant our {VestingClaim} contract the ability to mint floor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(vestingClaim));
    }

    function test_CanSetAllocation() public {
        assertEq(vestingClaim.redeemableFor(alice), 0);
        assertEq(vestingClaim.redeemableFor(bob), 0);
        assertEq(vestingClaim.redeemableFor(carol), 0);
        assertEq(vestingClaim.redeemableFor(david), 0);

        address[] memory _address = new address[](3);
        _address[0] = alice;
        _address[1] = bob;
        _address[2] = carol;

        uint[] memory _amount = new uint[](3);
        _amount[0] = 1 ether;
        _amount[1] = 5 ether;
        _amount[2] = 3 ether;

        vestingClaim.setAllocation(_address, _amount);

        assertEq(vestingClaim.redeemableFor(alice), 1 ether);
        assertEq(vestingClaim.redeemableFor(bob), 5 ether);
        assertEq(vestingClaim.redeemableFor(carol), 3 ether);
        assertEq(vestingClaim.redeemableFor(david), 0);
    }

    function test_CanSetEmptyAllocation() public {
        assertEq(vestingClaim.redeemableFor(alice), 0);
        assertEq(vestingClaim.redeemableFor(bob), 0);
        assertEq(vestingClaim.redeemableFor(carol), 0);
        assertEq(vestingClaim.redeemableFor(david), 0);

        address[] memory _address = new address[](0);
        uint[] memory _amount = new uint[](0);

        vestingClaim.setAllocation(_address, _amount);

        assertEq(vestingClaim.redeemableFor(alice), 0);
        assertEq(vestingClaim.redeemableFor(bob), 0);
        assertEq(vestingClaim.redeemableFor(carol), 0);
        assertEq(vestingClaim.redeemableFor(david), 0);
    }

    function test_CanUpdateAllocationAmounts() public {
        address[] memory _address = new address[](3);
        _address[0] = alice;
        _address[1] = bob;
        _address[2] = carol;

        uint[] memory _amount = new uint[](3);
        _amount[0] = 1 ether;
        _amount[1] = 5 ether;
        _amount[2] = 3 ether;

        vestingClaim.setAllocation(_address, _amount);

        assertEq(vestingClaim.redeemableFor(alice), 1 ether);
        assertEq(vestingClaim.redeemableFor(bob), 5 ether);
        assertEq(vestingClaim.redeemableFor(carol), 3 ether);
        assertEq(vestingClaim.redeemableFor(david), 0);

        vestingClaim.setAllocation(_address, _amount);

        assertEq(vestingClaim.redeemableFor(alice), 2 ether);
        assertEq(vestingClaim.redeemableFor(bob), 10 ether);
        assertEq(vestingClaim.redeemableFor(carol), 6 ether);
        assertEq(vestingClaim.redeemableFor(david), 0);

        vm.prank(alice);
        vestingClaim.claim(alice, 1 ether);

        vestingClaim.setAllocation(_address, _amount);

        assertEq(vestingClaim.redeemableFor(alice), 2 ether);
        assertEq(vestingClaim.redeemableFor(bob), 15 ether);
        assertEq(vestingClaim.redeemableFor(carol), 9 ether);
        assertEq(vestingClaim.redeemableFor(david), 0);
    }

    function test_CanClaimAllocation() public {
        assertEq(vestingClaim.redeemableFor(alice), 0);

        _setSingleAllocation(alice, 10 ether);

        assertEq(vestingClaim.redeemableFor(alice), 10 ether);

        vm.prank(alice);
        vestingClaim.claim(alice, 10 ether);

        assertEq(vestingClaim.redeemableFor(alice), 0);

        assertEq(newFloor.balanceOf(alice), 10 ether);
        assertEq(newFloor.balanceOf(bob), 0);
        assertEq(newFloor.balanceOf(treasury), 0);

        assertEq(weth.balanceOf(alice), startBalance - (claimCost * 10));
        assertEq(weth.balanceOf(bob), 0);
        assertEq(weth.balanceOf(treasury), claimCost * 10);
    }

    function test_CanPartiallyClaimAllocation() public {
        assertEq(vestingClaim.redeemableFor(alice), 0);

        _setSingleAllocation(alice, 10 ether);

        assertEq(vestingClaim.redeemableFor(alice), 10 ether);

        vm.prank(alice);
        vestingClaim.claim(alice, 5 ether);

        assertEq(vestingClaim.redeemableFor(alice), 5 ether);

        assertEq(newFloor.balanceOf(alice), 5 ether);
        assertEq(newFloor.balanceOf(bob), 0);
        assertEq(newFloor.balanceOf(treasury), 0);

        assertEq(weth.balanceOf(alice), 10 ether - (claimCost * 5));
        assertEq(weth.balanceOf(bob), 0);
        assertEq(weth.balanceOf(treasury), claimCost * 5);

        vm.prank(alice);
        vestingClaim.claim(alice, 5 ether);

        assertEq(vestingClaim.redeemableFor(alice), 0);

        assertEq(newFloor.balanceOf(alice), 10 ether);
        assertEq(newFloor.balanceOf(bob), 0);
        assertEq(newFloor.balanceOf(treasury), 0);

        assertEq(weth.balanceOf(alice), 10 ether - (claimCost * 10));
        assertEq(weth.balanceOf(bob), 0);
        assertEq(weth.balanceOf(treasury), claimCost * 10);
    }

    function test_CanClaimAllocationForAnotherUser() public {
        assertEq(vestingClaim.redeemableFor(alice), 0);

        _setSingleAllocation(alice, 10 ether);

        assertEq(vestingClaim.redeemableFor(alice), 10 ether);

        vm.prank(alice);
        vestingClaim.claim(bob, 10 ether);

        assertEq(vestingClaim.redeemableFor(alice), 0);

        assertEq(newFloor.balanceOf(alice), 0);
        assertEq(newFloor.balanceOf(bob), 10 ether);
        assertEq(newFloor.balanceOf(treasury), 0);

        assertEq(weth.balanceOf(alice), 10 ether - (claimCost * 10));
        assertEq(weth.balanceOf(bob), 0);
        assertEq(weth.balanceOf(treasury), claimCost * 10);
    }

    function test_CannotClaimAboveAllocationAmount(uint claim) public {
        vm.assume(claim > 10 ether);

        _setSingleAllocation(alice, 10 ether);

        vm.prank(alice);
        vm.expectRevert('Insufficient allocation');
        vestingClaim.claim(alice, claim);

        assertEq(newFloor.balanceOf(alice), 0);
        assertEq(weth.balanceOf(alice), startBalance);
    }

    function test_CannotClaimZeroAllocation() public {
        _setSingleAllocation(alice, 10 ether);

        vm.startPrank(alice);

        vm.expectRevert('Invalid amount');
        vestingClaim.claim(alice, 0);

        vm.stopPrank();
    }

    function test_CannotClaimWhenNoAmountAllocated(uint claim) public {
        vm.assume(claim > 0);

        vm.prank(alice);
        vm.expectRevert('Insufficient allocation');
        vestingClaim.claim(alice, claim);
    }

    function test_CannotClaimWithInsufficientWeth(uint amount, uint balance) public {
        amount = bound(amount, 4 ether, type(uint).max);
        vm.assume(amount % 1e3 == 0);
        vm.assume(balance < amount / 1e4);

        weth.mint(bob, balance);

        vm.prank(bob);
        weth.approve(address(vestingClaim), balance);

        _setSingleAllocation(bob, amount);

        vm.prank(bob);
        vm.expectRevert('ERC20: insufficient allowance');
        vestingClaim.claim(bob, amount);
    }

    function test_CannotClaimInvalidAmount(uint amount) public {
        // Ensure that the amount is invalid, by either being zero, or not modulus of 1e3
        vm.assume(amount == 0 || amount % 1e3 != 0);

        // Set Alice a sufficient allocation
        _setSingleAllocation(alice, amount);

        vm.startPrank(alice);

        // Make a claim that, although sufficiently allocated, is an invalid amount
        vm.expectRevert('Invalid amount');
        vestingClaim.claim(alice, amount);

        vm.stopPrank();
    }

    function _setSingleAllocation(address _address, uint _amount) internal {
        address[] memory allocationAddress = new address[](1);
        allocationAddress[0] = _address;

        uint[] memory allocationAmount = new uint[](3);
        allocationAmount[0] = _amount;

        vestingClaim.setAllocation(allocationAddress, allocationAmount);
    }
}
