// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract RevenueStakingStrategyTest is FloorTest {

    // Store our staking strategy
    RevenueStakingStrategy strategy;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_126_124;

    // NFTX DAO - Holds 50.242376308170344638 $PUNK at block
    address testUser = 0xaA29881aAc939A025A3ab58024D7dd46200fB93D;

    // Set some constants for our test tokens
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant PUNK = 0x269616D549D7e8Eaa82DFb17028d0B212D11232A;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = PUNK;

        // Set up our pricing executor
        strategy = new RevenueStakingStrategy();
        strategy.initialize(
            bytes32('$PUNK/WETH ERC20 Strategy'),
            0, // Strategy ID
            abi.encode(tokens)
        );
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), '$PUNK/WETH ERC20 Strategy');
    }

    /**
     * ..
     */
    function test_CanGetTokens() public {
        address[] memory tokens = strategy.validTokens();
        assertEq(tokens[0], WETH);
        assertEq(tokens[1], PUNK);
    }

    /**
     *
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * This should return an xToken that is stored in the strategy.
     */
    function test_CanDepositToRevenueStaking() public {
        vm.startPrank(testUser);

        // Start with no deposits
        (address[] memory totalRewardTokens, uint[] memory totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardTokens[1], PUNK);
        assertEq(totalRewardAmounts[0], 0);
        assertEq(totalRewardAmounts[1], 0);

        // Confirm our test user's starting balance
        assertEq(IERC20(WETH).balanceOf(testUser), 78400000000000000000);
        assertEq(IERC20(PUNK).balanceOf(testUser), 50242376308170344638);

        // Confirm our strategies starting balance
        assertEq(IERC20(WETH).balanceOf(address(strategy)), 0);
        assertEq(IERC20(PUNK).balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(WETH).approve(address(strategy), 2 ether);
        IERC20(PUNK).approve(address(strategy), 1 ether);
        strategy.depositErc20(WETH, 2 ether);
        strategy.depositErc20(PUNK, 1 ether);

        // We should now see that tokens have transferred from user to strategy
        assertEq(IERC20(WETH).balanceOf(testUser), 76400000000000000000);
        assertEq(IERC20(PUNK).balanceOf(testUser), 49242376308170344638);
        assertEq(IERC20(WETH).balanceOf(address(strategy)), 2 ether);
        assertEq(IERC20(PUNK).balanceOf(address(strategy)), 1 ether);

        // Our total amount of rewards generated should also reflect these deposits
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardTokens[1], PUNK);
        assertEq(totalRewardAmounts[0], 2 ether);
        assertEq(totalRewardAmounts[1], 1 ether);

        // Using our snapshot call, register the tokens to be distributed
        (address[] memory snapshotTokens, uint[] memory snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotTokens[1], PUNK);
        assertEq(snapshotAmounts[0], 2 ether);
        assertEq(snapshotAmounts[1], 1 ether);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotTokens[1], PUNK);
        assertEq(snapshotAmounts[0], 0);
        assertEq(snapshotAmounts[1], 0);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardTokens[1], PUNK);
        assertEq(totalRewardAmounts[0], 2 ether);
        assertEq(totalRewardAmounts[1], 1 ether);

        vm.stopPrank();
    }

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function test_CannotDepositZeroValue() public {
        vm.startPrank(testUser);
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.depositErc20(WETH, 0);

        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.depositErc20(PUNK, 0);
        vm.stopPrank();
    }

    function test_CannotDepositUnknownToken() public {
        vm.startPrank(testUser);
        vm.expectRevert('Invalid token');
        strategy.depositErc20(address(0), 0);
        vm.stopPrank();
    }

}
