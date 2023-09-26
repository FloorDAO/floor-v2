// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract FloorTokenTest is FloorTest {
    // Store some test users
    address alice;
    address bob;

    // Reference our Floor token contract
    FLOOR floor;

    constructor() {
        // Deploy our authority contracts
        super._deployAuthority();

        // Deploy our FLOOR token contract
        floor = new FLOOR(address(authorityRegistry));

        // Set up our user references
        (alice, bob) = (users[0], users[1]);
    }

    function test_TokenIsValidERC20() public {
        assertEq(floor.name(), 'Floor');
        assertEq(floor.symbol(), 'FLOOR');
        assertEq(floor.decimals(), 18);
    }

    function test_CannotMintWithoutPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.FLOOR_MANAGER()));
        vm.prank(alice);
        floor.mint(alice, 100 ether);
    }

    function test_MintingIncreasesTotalSupply() public {
        uint supplyBefore = floor.totalSupply();

        floor.mint(alice, 100 ether);

        assertEq(floor.totalSupply(), supplyBefore + 100 ether);
    }

    function test_BurningReducedTotalSupply() public {
        uint supplyBefore = floor.totalSupply();

        // Mint 100 tokens to Alice
        floor.mint(alice, 100 ether);

        // Alice can now burn 10 tokens
        vm.prank(alice);
        floor.burn(10 ether);

        // The remaining supply should calculate based off the burn
        assertEq(floor.totalSupply(), supplyBefore + 90 ether);
    }
}
