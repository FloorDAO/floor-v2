// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LlamapayDeposit} from '@floor/actions/llamapay/Deposit.sol';
import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract LlamaPayDepositTest is FloorTest {
    // Store the maximum amount of WETH available to the user
    uint weth_balance = 79228162514264337593543950335;

    // Mainnet 0x swapTarget contract
    address internal constant LLAMAPAY_CONTRACT = 0xde1C04855c2828431ba637675B6929A684f84C7F;

    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

    // Store our action contract
    LlamapayDeposit action;
    LlamapayRouter llamapayRouter;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up our LlamaPay Router
        llamapayRouter = new LlamapayRouter(LLAMAPAY_CONTRACT);

        // Set up our action, using the test suite's address as the {Treasury}
        action = new LlamapayDeposit(llamapayRouter);
    }

    function setUp() external {
        // Wrap up some WETH that we can use as a deposit token
        IWETH(WETH).deposit{value: address(this).balance}();
    }

    function test_CanDepositTokenIntoStream(uint amount) external {
        // Set our amount assumptions to ensure that we have a non-zero amount, and
        // also that we have sufficient WETH to supply the stream.
        amount = bound(amount, 1, weth_balance);

        // Approve the action to use our WETH balance
        IWETH(WETH).approve(address(llamapayRouter), amount);

        // Action our deposit
        uint payerBalance = action.execute(abi.encode(WETH, amount));
        assertEq(payerBalance, amount);
    }

    function test_CannotDepositZeroValue() external {
        // Approve the action to use our WETH balance
        IWETH(WETH).approve(address(llamapayRouter), 1 ether);

        vm.expectRevert();
        action.execute(abi.encode(WETH, 0));
    }

    function test_CannotDepositIntoUnknownStream() external {
        vm.expectRevert();
        action.execute(abi.encode(address(this), 1 ether));
    }
}
