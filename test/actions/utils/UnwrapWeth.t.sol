// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IWETH} from '../../../src/interfaces/tokens/WETH.sol';

import {UnwrapWeth} from '../../../src/contracts/actions/utils/UnwrapWeth.sol';

import '../../utilities/Environments.sol';

contract UnwrapWethTest is FloorTest {

    // Store our action contract
    UnwrapWeth action;

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
        action = new UnwrapWeth(treasury);

        // Set up a WETH interface
        weth = IWETH(action.WETH());
    }

    function setUp() external {
        // Mint 100 WETH tokens to our {Treasury} for testing and approve the action
        // to user them.
        deal(address(weth), treasury, 100 ether);

        vm.prank(treasury);
        weth.approve(address(action), 100 ether);
    }

    function test_CanUnwrapWeth(uint amount) external {
        // Ensure that our fuzz amount is always less that the balance of our
        // test account.
        vm.assume(amount <= weth.balanceOf(treasury));

        // Confirm the ETH and WETH balances of our two accounts pre-wrap
        uint userEthPreWrap = address(this).balance;
        uint userWethPreWrap = weth.balanceOf(address(this));
        uint treasuryEthPreWrap = address(treasury).balance;
        uint treasuryWethPreWrap = weth.balanceOf(treasury);

        // Action our wrap
        uint amountOut = action.execute(abi.encode(amount));
        assertEq(amount, amountOut);

        // Confirm our closing balances reflect the wrapped amounts
        assertEq(address(this).balance, userEthPreWrap);
        assertEq(weth.balanceOf(address(this)), userWethPreWrap);
        assertEq(address(treasury).balance, treasuryEthPreWrap + amount);
        assertEq(weth.balanceOf(treasury), treasuryWethPreWrap - amount);
    }

    function test_CannotWrapEthWithInsufficientBalance(uint amount) external {
        // Ensure that our fuzz amount is above the balance held
        vm.assume(amount > weth.balanceOf(treasury));

        // Action our wrap
        vm.expectRevert();
        action.execute(abi.encode(amount));
    }

}
