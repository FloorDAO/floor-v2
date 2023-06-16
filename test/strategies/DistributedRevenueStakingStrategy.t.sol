// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, InsufficientPosition, DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

/**
 * TODO:
 * - IF DEPOSIT AT EPOCH 0, THEN THIS SHOULD REFLECT THE YIELD FOR THAT SAME EPOCH.
 */

contract DistributedRevenueStakingStrategyTest is FloorTest {
    // Store our staking strategy
    DistributedRevenueStakingStrategy strategy;
    EpochManager epochManager;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_126_124;

    // NFTX DAO - Holds 50.242376308170344638 $PUNK at block
    address testUser = 0xaA29881aAc939A025A3ab58024D7dd46200fB93D;

    // Set some constants for our test tokens
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        epochManager = new EpochManager();

        strategy = new DistributedRevenueStakingStrategy();
        strategy.setEpochManager(address(epochManager));
        strategy.initialize(
            bytes32('WETH Rewards Strategy'),
            0, // Strategy ID
            abi.encode(WETH, 20 ether)
        );
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'WETH Rewards Strategy');
    }

    /**
     * ..
     */
    function test_CanGetTokens() public {
        address[] memory tokens = strategy.validTokens();
        assertEq(tokens[0], WETH);
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
        // Start with no deposits
        (address[] memory totalRewardTokens, uint[] memory totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 0);

        // Confirm our test user's starting balance
        assertEq(IERC20(WETH).balanceOf(testUser), 78.4 ether);

        // Confirm our strategies starting balance
        assertEq(IERC20(WETH).balanceOf(address(strategy)), 0);

        vm.startPrank(testUser);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(WETH).approve(address(strategy), 50 ether);
        strategy.depositErc20(50 ether);

        vm.stopPrank();

        // We should now see that tokens have transferred from user to strategy
        assertEq(IERC20(WETH).balanceOf(testUser), 28.4 ether);
        assertEq(IERC20(WETH).balanceOf(address(strategy)), 50 ether);

        // Confirm our distributed epoch yields
        assertEq(strategy.epochYield(0), 20 ether);
        assertEq(strategy.epochYield(1), 20 ether);
        assertEq(strategy.epochYield(2), 10 ether);
        assertEq(strategy.epochYield(3), 0 ether);

        // Our total amount of rewards generated should only reflect rewards that are available
        // to collect at the current epoch. This would be zero currently as only rewards from
        // past epochs can be collected.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 20 ether);

        // Using our snapshot call, register the tokens to be distributed
        (address[] memory snapshotTokens, uint[] memory snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 20 ether);

        // If we shift our epoch forwards we should see that we now have 20 ether
        // allocation of our rewards.
        epochManager.setCurrentEpoch(1);

        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 20 ether);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0 ether);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 40 ether);

        // Our last snapshot call should only hold the remaining 20 + 10 ETH
        epochManager.setCurrentEpoch(2);
        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 10 ether);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0 ether);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 50 ether);

        // Shifting to after our epoch deposits, we should no longer have rewards
        epochManager.setCurrentEpoch(3);
        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0 ether);
    }

    function test_CanMakeStaggeredDeposits() public {
        // Confirm our test user's starting balance
        assertEq(IERC20(WETH).balanceOf(testUser), 78.4 ether);

        // Confirm our strategies starting balance
        assertEq(IERC20(WETH).balanceOf(address(strategy)), 0);

        // Approve our test user to deposit plenty of tokens
        vm.prank(testUser);
        IERC20(WETH).approve(address(strategy), 70 ether);

        // Deposit an initial 30 ether
        vm.prank(testUser);
        strategy.depositErc20(30 ether);

        // Confirm our distributed epoch yields
        assertEq(strategy.epochYield(0), 20 ether);
        assertEq(strategy.epochYield(1), 10 ether);
        assertEq(strategy.epochYield(2), 0 ether);
        assertEq(strategy.epochYield(3), 0 ether);

        // Deposit another 15 ether
        vm.prank(testUser);
        strategy.depositErc20(15 ether);

        // Confirm our distributed epoch yields
        assertEq(strategy.epochYield(0), 20 ether);
        assertEq(strategy.epochYield(1), 20 ether);
        assertEq(strategy.epochYield(2), 5 ether);
        assertEq(strategy.epochYield(3), 0 ether);

        // Wait until the third epoch and then deposit an additional ether to show that
        // it is distributed from the current epoch onwards.
        epochManager.setCurrentEpoch(3);

        // Deposit another 5 ether
        vm.prank(testUser);
        strategy.depositErc20(5 ether);

        // Confirm our distributed epoch yields
        assertEq(strategy.epochYield(0), 20 ether);
        assertEq(strategy.epochYield(1), 20 ether);
        assertEq(strategy.epochYield(2), 5 ether);
        assertEq(strategy.epochYield(3), 5 ether);
    }

    function test_CanWithdrawInValidEpochs() public {
        // Deposit enough ETH to fill all our upcoming epochs
        vm.startPrank(testUser);
        IERC20(WETH).approve(address(strategy), 50 ether);
        strategy.depositErc20(50 ether);
        vm.stopPrank();

        // Try and withdraw from current epoch
        strategy.withdrawErc20(address(this));
        assertEq(IERC20(WETH).balanceOf(address(this)), 0);

        // Move our epoch forwards
        epochManager.setCurrentEpoch(1);

        // Confirm we can withdraw from past epoch
        strategy.withdrawErc20(address(this));
        assertEq(IERC20(WETH).balanceOf(address(this)), 20 ether);

        // Withdraw from same epoch, which should yield no additional ether, but also
        // not revert.
        strategy.withdrawErc20(address(this));
        assertEq(IERC20(WETH).balanceOf(address(this)), 20 ether);

        // Move our epoch forward to last one
        epochManager.setCurrentEpoch(3);

        // Confirm we can withdraw from past epochs, but trying to withdraw from
        // current epoch will revert.
        strategy.withdrawErc20(address(this));
        assertEq(IERC20(WETH).balanceOf(address(this)), 50 ether);
    }

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function test_CannotDepositZeroValue() public {
        vm.startPrank(testUser);
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.depositErc20(0);
    }

}
