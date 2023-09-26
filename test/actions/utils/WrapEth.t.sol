// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {WrapEth} from '@floor/actions/utils/WrapEth.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract WrapEthTest is FloorTest {
    // Store our action contract
    WrapEth action;

    // Define our WETH interface
    IWETH weth;

    // Store our mainnet fork information to access the WETH contract
    uint internal constant BLOCK_NUMBER = 16_134_863;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Set up a WETH interface
        weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        // Set up a WrapEth action
        action = new WrapEth(address(weth));
    }

    function test_CanWrapEth(uint amount) external {
        // Ensure that our fuzz amount is always less that the balance of our
        // test account.
        vm.assume(amount <= address(this).balance);

        // Confirm the ETH and WETH balances
        uint ethPreWrap = address(this).balance;
        uint wethPreWrap = weth.balanceOf(address(this));

        // Action our wrap
        action.execute{value: amount}(abi.encode(amount));

        // Confirm our closing balances reflect the wrapped amounts
        assertEq(address(this).balance, ethPreWrap - amount);
        assertEq(weth.balanceOf(address(this)), wethPreWrap + amount);
    }

    function test_CanReceiveRefundIfMsgValueHigherThanAmount(uint amount, uint value) external {
        vm.assume(value <= address(this).balance);
        vm.assume(amount < value);

        uint ethPreWrap = address(this).balance;
        uint wethPreWrap = weth.balanceOf(address(this));

        action.execute{value: amount}(abi.encode(amount));

        assertEq(address(this).balance, ethPreWrap - amount);
        assertEq(weth.balanceOf(address(this)), wethPreWrap + amount);
    }

    function test_CannotSendLessMsgValueThanAmount(uint amount, uint value) external {
        vm.assume(value <= address(this).balance);
        vm.assume(amount > value);

        vm.expectRevert('Insufficient msg.value');
        action.execute{value: value}(abi.encode(amount));
    }

    function test_CannotWrapEthWithInsufficientBalance(uint amount) external {
        // Ensure that our fuzz amount is above the balance held
        vm.assume(amount > address(this).balance);

        // Action our wrap
        vm.expectRevert();
        action.execute{value: amount}(abi.encode(amount));
    }
}
