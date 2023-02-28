// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LlamapayDeposit} from '@floor/actions/llamapay/Deposit.sol';
import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';
import {LlamapayWithdraw} from '@floor/actions/llamapay/Withdraw.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';


contract LlamaPayWithdrawTest is FloorTest {

    // Store the maximum amount of WETH available to the user
    uint weth_balance = 79228162514264337593543950335;

    // Mainnet 0x swapTarget contract
    address internal constant LLAMAPAY_CONTRACT = 0xde1C04855c2828431ba637675B6929A684f84C7F;

    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

    // Store our action contract
    LlamapayDeposit depositAction;
    LlamapayRouter llamapayRouter;
    LlamapayWithdraw action;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up our LlamaPay Router
        llamapayRouter = new LlamapayRouter(LLAMAPAY_CONTRACT, address(this));

        // Set up our action, using the test suite's address as the {Treasury}
        action = new LlamapayWithdraw(llamapayRouter);

        // Set up our deposit action
        depositAction = new LlamapayDeposit(llamapayRouter);
    }

    function setUp() external {
        // Wrap up some WETH that we can use as a deposit token
        IWETH(WETH).deposit{value: address(this).balance}();

        // Make a deposit into the LlamaPay contract that we can withdraw from in
        // subsequent tests.
        IWETH(WETH).approve(address(llamapayRouter), 5 ether);
        uint payerBalance = depositAction.execute(abi.encode(WETH, 5 ether));
        assertEq(payerBalance, 5 ether);
    }

    function test_CanWithdrawFromStream(uint amount) external {
        amount = bound(amount, 1 ether, 5 ether);
        action.execute(abi.encode(WETH, amount));
    }

    function test_CannotWithdrawMoreThanAvailable() external {
        // We can request to withdraw more than our limit, but it just won't
        // action it. Our payer balance will still be as before.
        uint payerBalance = action.execute(abi.encode(WETH, 100 ether));
        assertFalse(payerBalance == 0);
    }

    function test_CanWithdrawZeroAmountToGetAll() external {
        uint payerBalance = action.execute(abi.encode(WETH, 0));
        assertEq(payerBalance, 0);
    }

}
