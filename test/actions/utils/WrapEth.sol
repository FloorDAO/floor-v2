// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IWETH} from '../../../src/interfaces/tokens/WETH.sol';

import {WrapEth} from '../../../src/contracts/actions/utils/WrapEth.sol';

import '../../utilities/Environments.sol';

contract WrapEthTest is FloorTest {

    // Store our action contract
    WrapEth action;

    // Store the treasury address
    address treasury;

    // Define our WETH interface
    IWETH weth;

    // Store our mainnet fork information to access the WETH contract
    uint internal constant BLOCK_NUMBER = 16_134_863;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a test address to be our {Treasury}
        treasury = users[1];

        // Set up a WrapEth action
        action = new WrapEth(treasury);

        // Set up a WETH interface
        weth = IWETH(action.WETH());
    }

    function test_CanWrapEth(uint amount) external {
        // Ensure that our fuzz amount is always less that the balance of our
        // test account.
        vm.assume(amount <= address(treasury).balance);

        // Confirm the ETH and WETH balances of our two accounts pre-wrap
        uint userEthPreWrap = address(this).balance;
        uint userWethPreWrap = weth.balanceOf(address(this));
        uint treasuryEthPreWrap = address(treasury).balance;
        uint treasuryWethPreWrap = weth.balanceOf(treasury);

        // Action our wrap
        vm.prank(treasury);
        action.execute{value: amount}('');

        // Confirm our closing balances reflect the wrapped amounts
        assertEq(address(this).balance, userEthPreWrap);
        assertEq(weth.balanceOf(address(this)), userWethPreWrap);
        assertEq(address(treasury).balance, treasuryEthPreWrap - amount);
        assertEq(weth.balanceOf(treasury), treasuryWethPreWrap + amount);
    }

    function test_CannotWrapEthWithInsufficientBalance(uint amount) external {
        // Ensure that our fuzz amount is above the balance held
        vm.assume(amount > address(this).balance);

        // Action our wrap
        vm.expectRevert();
        action.execute{value: amount}('');
    }

}
