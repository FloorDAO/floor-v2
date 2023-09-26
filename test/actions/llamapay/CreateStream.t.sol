// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LlamapayCreateStream} from '@floor/actions/llamapay/CreateStream.sol';
import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract LlamaPayCreateStreamTest is FloorTest {
    // Store our recipient test user
    address alice;
    address bob;

    // Store the maximum amount of WETH available to the user
    uint weth_balance = 79228162514264337593543950335;

    // Mainnet 0x swapTarget contract
    address internal constant LLAMAPAY_CONTRACT = 0xde1C04855c2828431ba637675B6929A684f84C7F;

    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

    // Store our action contract
    LlamapayCreateStream action;
    LlamapayRouter llamapayRouter;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Set up our recipient test user
        alice = users[1];
        bob = users[2];

        // Set up our LlamaPay Router
        llamapayRouter = new LlamapayRouter(LLAMAPAY_CONTRACT);

        // Set up our action, using the test suite's address as the {Treasury}
        action = new LlamapayCreateStream(llamapayRouter);
    }

    function setUp() external {
        // Wrap up some WETH that we can use as a deposit token
        IWETH(WETH).deposit{value: address(this).balance}();
    }

    function test_CanCreateStreamWithNewFunds(uint amount) external {
        // Set our amount assumptions to ensure that we have enough to divide per
        // second, and also that we have sufficient WETH to supply the stream.
        amount = bound(amount, 3600, weth_balance);

        // Approve the action to use our WETH balance
        IWETH(WETH).approve(address(llamapayRouter), amount);

        // Action our stream creation with deposit
        uint payerBalance = action.execute(
            abi.encode(
                alice, // to
                WETH, // token
                uint216(amount / 3600), // amountPerSec
                amount // amountToDeposit
            )
        );

        assertEq(payerBalance, amount);
    }

    function test_CanCreateStreamWithExistingFunds() external {
        // Approve the action to use our WETH balance
        IWETH(WETH).approve(address(llamapayRouter), 1 ether);

        // Set up our initial stream with a deposit. This logic is testing previously
        uint startPayerBalance = action.execute(abi.encode(alice, WETH, uint216(1), 1 ether));

        // We can now create an additional stream that piggy backs off the existing
        // 1 ether supply.
        uint newPayerBalance = action.execute(abi.encode(bob, WETH, uint216(1), 0));

        assertEq(startPayerBalance, 1 ether);
        assertEq(newPayerBalance, 1 ether);
    }

    function test_CannotCreateStreamWithoutSufficientFunds() external {
        vm.expectRevert();
        action.execute(abi.encode(alice, WETH, uint216(1), 1 ether));
    }
}
