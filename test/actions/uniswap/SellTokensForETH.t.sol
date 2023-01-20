// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../../../src/contracts/actions/uniswap/SellTokensForETH.sol';

import '../../utilities/Environments.sol';

contract UniswapSellTokensForETHTest is FloorTest {
    // Set up our Router02 address
    address internal constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // We will be using USDC as our base token
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // The pool fee for USDC/ETH is 0.05%
    uint24 internal constant USDC_FEE = 500;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_016_064;

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
        treasury = 0x15abb66bA754F05cBC0165A64A11cDed1543dE48;

        // Set up a floor migration contract
        action = new UniswapSellTokensForETH(UNISWAP_ROUTER, treasury);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanSwapToken() public {
        vm.startPrank(treasury);

        // Approve $10,000 against the action contract
        ERC20(USDC).approve(address(action), 10000000000);

        // Action our trade
        uint amountOut = action.execute(
            abi.encode(
                address(USDC), // token0
                uint24(USDC_FEE), // fee
                uint(10000000000), // amountIn
                uint(1), // amountOutMinimum
                uint(block.timestamp) // deadline
            )
        );

        // Confirm that we received 8.8~ ETH
        assertEq(amountOut, 8_862042781469125242);

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

        vm.expectRevert('Too little received');
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
