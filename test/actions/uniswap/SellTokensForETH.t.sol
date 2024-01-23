// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {UniswapSellTokensForETH} from '@floor/actions/uniswap/SellTokensForETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract UniswapSellTokensForETHTest is FloorTest {
    // Set up our Universal Router address
    address internal constant UNISWAP_ROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;

    // We will be using USDC as our base token and WETH as the received token
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // The pool fee for USDC/ETH is 0.05%
    uint24 internal constant USDC_FEE = 500;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_427_661;

    // Store our action contract
    UniswapSellTokensForETH action;

    // Store the treasury address
    address treasury;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up our Treasury. In this test we will just use an account that
        // we know has the tokens that we need. This test will need to be updated
        // when our {Treasury} contract is completed.
        treasury = 0x171cda359aa49E46Dec45F375ad6c256fdFBD420;

        // Set up a floor migration contract
        action = new UniswapSellTokensForETH(UNISWAP_ROUTER, WETH);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanSwapToken() public {
        vm.startPrank(treasury);

        // Approve our entire USDC balance
        ERC20(USDC).approve(address(action), type(uint).max);

        // Confirm our starting balances
        assertEq(ERC20(USDC).balanceOf(treasury), 76980271562891);
        assertEq(ERC20(WETH).balanceOf(treasury), 0);

        // Action our trade
        action.execute(
            abi.encode(
                address(USDC), // token0
                uint24(USDC_FEE), // fee
                uint(10000000000), // amountIn
                uint(1), // amountOutMinimum
                uint(block.timestamp) // deadline
            )
        );

        // Confirm our closing balances, showing $1,000 spent and 5.3~ WETH received
        assertEq(ERC20(USDC).balanceOf(treasury), 76970271562891);
        assertEq(ERC20(WETH).balanceOf(treasury), 5359638946275081829);

        vm.stopPrank();
    }

    /**
     * If we don't have sufficient approved balance when we request our swap, then
     * the transaction should be reverted.
     */
    function test_CannotSwapTokenWithInsufficientBalance() public {
        vm.startPrank(treasury);

        // Don't approve any tokens

        vm.expectRevert();
        action.execute(
            abi.encode(
                USDC, // token0
                USDC_FEE, // fee
                uint(10000000000), // amountIn
                uint(0), // amountOutMinimum
                block.timestamp // deadline
            )
        );

        vm.stopPrank();
    }

    /**
     * If our swap generates an amount of WETH below the amount we specify, then we
     * expect the transaction to be reverted.
     */
    function test_CannotSwapWithInsufficientAmountOutResponse() public {
        vm.startPrank(treasury);

        // Approve $10,000 against the action contract
        ERC20(USDC).approve(address(action), 10000000000);

        vm.expectRevert();
        action.execute(
            abi.encode(
                USDC, // token0
                USDC_FEE, // fee
                uint(10000000000), // amountIn
                uint(100 ether), // amountOutMinimum
                block.timestamp // deadline
            )
        );

        vm.stopPrank();
    }
}
