// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {
    CannotDepositZeroAmount,
    CannotWithdrawZeroAmount,
    InsufficientPosition,
    DistributedRevenueStakingStrategy
} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract DistributedRevenueStakingStrategyTest is FloorTest {
    // Store our staking strategy
    CollectionRegistry collectionRegistry;
    DistributedRevenueStakingStrategy strategy;
    EpochManager epochManager;
    StrategyFactory strategyFactory;

    /// Store our strategy ID
    uint strategyId;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_126_124;

    // NFTX DAO - Holds 50.242376308170344638 $PUNK at block
    address testUser = 0xaA29881aAc939A025A3ab58024D7dd46200fB93D;

    // Set some constants for our test tokens
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        // Create our {EpochManager}
        epochManager = new EpochManager();

        // Create our {CollectionRegistry} and approve our collection
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        collectionRegistry.approveCollection(0x5Af0D9827E0c53E4799BB226655A1de152A425a5, 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48);

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(address(authorityRegistry), address(collectionRegistry));

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('WETH Rewards Strategy'),
            address(new DistributedRevenueStakingStrategy(address(authorityRegistry))),
            abi.encode(WETH, 20 ether, address(epochManager)),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = DistributedRevenueStakingStrategy(_strategy);
        strategyId = _strategyId;
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'WETH Rewards Strategy');
    }

    /**
     * Ensures that we have the correct tokens attached to the strategy.
     */
    function test_CanGetTokens() public {
        address[] memory tokens = strategy.validTokens();
        assertEq(tokens[0], WETH);
    }

    /**
     * Ensures that we can correctly find the strategy ID that was deployed with the strategy.
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * This should return an xToken that is stored in the strategy.
     */
    function test_CanDepositToRevenueStaking() public {
        /**========================================
         * Set up
         */

        // Start with no deposits
        (address[] memory totalRewardTokens, uint[] memory totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 0);

        // We should have nothing available for the strategy either
        (address[] memory availableTokens, uint[] memory availableAmounts) = strategy.available();
        assertEq(availableTokens[0], WETH);
        assertEq(availableAmounts[0], 0);

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

        /**========================================
         * Epoch 0 - Should have nothing available
         */

        // Our total amount of rewards generated should only reflect rewards that are available
        // to collect at the current epoch. This would be zero currently as only rewards from
        // past epochs can be collected.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 0);

        // Before the snapshot we should have 0 tokens available, as this is the total amount that
        // can be withdrawn at this epoch. This would be zero currently as only rewards from past
        // epochs can be collected.
        (availableTokens, availableAmounts) = strategy.available();
        assertEq(availableTokens[0], WETH);
        assertEq(availableAmounts[0], 0);

        // If we call snapshot, then we shouldn't be able to get anything as it is not ready until
        // the next epoch.
        (address[] memory snapshotTokens, uint[] memory snapshotAmounts) = strategyFactory.snapshot(strategyId, epochManager.currentEpoch());
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0);

        /**========================================
         * Epoch 1 - Should have access to the epochYield at 0
         */

        // If we shift our epoch forwards we should see that we now have 20 ether
        // allocation of our rewards.
        setCurrentEpoch(address(epochManager), 1);

        // Our total amount of rewards generated should only reflect rewards that are available
        // to collect at the current epoch.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 20 ether);

        // Our snapshot will now yield 20 ether
        (snapshotTokens, snapshotAmounts) = strategyFactory.snapshot(strategyId, epochManager.currentEpoch());
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 20 ether);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotTokens, snapshotAmounts) = strategyFactory.snapshot(strategyId, epochManager.currentEpoch());
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0 ether);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 20 ether);

        /**========================================
         * Epoch 3 - Should have access to the epochYield at 1 and 2
         */

        // Our last snapshot call should only hold the remaining 20 ETH + 10 ETH
        setCurrentEpoch(address(epochManager), 3);

        // Our total amount of rewards generated, and the available yield, should reflect both
        // the rewards from epoch 1 and epoch 2, as we did not previously claim.
        // to collect at the current epoch.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 50 ether);

        (snapshotTokens, snapshotAmounts) = strategyFactory.snapshot(strategyId, epochManager.currentEpoch());
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 30 ether);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotTokens, snapshotAmounts) = strategyFactory.snapshot(strategyId, epochManager.currentEpoch());
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0 ether);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 50 ether);

        /**========================================
         * Epoch 4 - Should have no tokens remaining to claim
         */

        // Shifting to after our epoch deposits, we should no longer have rewards
        setCurrentEpoch(address(epochManager), 4);

        // No additional rewards will have been generated, and we should see the total amounts
        // available shown in both `totalRewards` and `available`.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 50 ether);

        (snapshotTokens, snapshotAmounts) = strategyFactory.snapshot(strategyId, epochManager.currentEpoch());
        assertEq(snapshotTokens[0], WETH);
        assertEq(snapshotAmounts[0], 0 ether);
    }

    /**
     * If we make deposits over multple epochs, we need to ensure that the amounts start
     * from the current epoch and then stagger over the coming epochs if there is overflow.
     */
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
        setCurrentEpoch(address(epochManager), 3);

        // Deposit another 5 ether
        vm.prank(testUser);
        strategy.depositErc20(5 ether);

        // Confirm our distributed epoch yields
        assertEq(strategy.epochYield(0), 20 ether);
        assertEq(strategy.epochYield(1), 20 ether);
        assertEq(strategy.epochYield(2), 5 ether);
        assertEq(strategy.epochYield(3), 5 ether);
    }

    /**
     * Ensure that we can only withdraw in valid, past epochs that have available yield
     */
    function test_CanWithdrawInValidEpochs() public {
        // Deposit enough ETH to fill all our upcoming epochs
        vm.startPrank(testUser);
        IERC20(WETH).approve(address(strategy), 50 ether);
        strategy.depositErc20(50 ether);
        vm.stopPrank();

        // For the purposes of this test, we set the {Treasury} to this test contract
        strategyFactory.setTreasury(address(this));

        // Try and withdraw from current epoch. This should return nothing as we aren't currently
        // in an epoch that would allow it.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector));
        assertEq(IERC20(WETH).balanceOf(address(this)), 0);

        // Move our epoch forwards
        setCurrentEpoch(address(epochManager), 1);

        // We should see that our total rewards is 20 ether, and we have 20 ether available to
        // withdraw against.
        (address[] memory totalRewardTokens, uint[] memory totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 20 ether);
        (address[] memory availableTokens, uint[] memory availableAmounts) = strategy.available();
        assertEq(availableTokens[0], WETH);
        assertEq(availableAmounts[0], 20 ether);

        // Confirm we can withdraw from past epochs, which would be 20 ether in total
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector));
        assertEq(IERC20(WETH).balanceOf(address(this)), 20 ether);

        // Withdraw from same epoch, which should yield no additional ether, but also
        // not revert.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector));
        assertEq(IERC20(WETH).balanceOf(address(this)), 20 ether);

        // After our withdrawal, we should still see that the total rewards amount is 20 ether, but
        // our available rewards will no longer show the 20 ether.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 20 ether);
        (availableTokens, availableAmounts) = strategy.available();
        assertEq(availableTokens[0], WETH);
        assertEq(availableAmounts[0], 0);

        // Move our epoch forward to last one
        setCurrentEpoch(address(epochManager), 3);

        // Before our withdrawal, because we have skipped over 2 epochs we should have a summary
        // in the `totalRewards` and the reduced total in `available`.
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 50 ether);
        (availableTokens, availableAmounts) = strategy.available();
        assertEq(availableTokens[0], WETH);
        assertEq(availableAmounts[0], 30 ether);

        // Confirm we can withdraw from past epochs, but trying to withdraw from
        // current epoch will revert.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector));
        assertEq(IERC20(WETH).balanceOf(address(this)), 50 ether);

        // After processing a successful withdrawal, our `available` amount will have been reduced
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], WETH);
        assertEq(totalRewardAmounts[0], 50 ether);
        (availableTokens, availableAmounts) = strategy.available();
        assertEq(availableTokens[0], WETH);
        assertEq(availableAmounts[0], 0);
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

    /**
     * Confirm that we can update the amount distributed per epoch on a strategy.
     */
    function test_CanSetMaxEpochYield(uint _maxEpochYield1, uint _maxEpochYield2) external {
        vm.assume(_maxEpochYield1 != 0);
        vm.assume(_maxEpochYield2 != 0);

        // Confirm that the correct amount is mapped on creation
        assertEq(strategy.maxEpochYield(), 20 ether);

        // Confirm we can set it to a new value
        strategy.setMaxEpochYield(_maxEpochYield1);
        assertEq(strategy.maxEpochYield(), _maxEpochYield1);

        // Confirm we cannot set it to the same value, as this would just take gas
        vm.expectRevert('Cannot set same value');
        strategy.setMaxEpochYield(_maxEpochYield1);

        // Confirm we can change the value again
        strategy.setMaxEpochYield(_maxEpochYield2);
        assertEq(strategy.maxEpochYield(), _maxEpochYield2);

        // Confirm we can change it back again
        strategy.setMaxEpochYield(_maxEpochYield1);
        assertEq(strategy.maxEpochYield(), _maxEpochYield1);

        // Confirm we cannot set it to a zero value
        vm.expectRevert('Cannot set zero yield');
        strategy.setMaxEpochYield(0);

        // Confirm that a non-permissioned user cannot call it
        vm.prank(users[1]);
        vm.expectRevert();
        strategy.setMaxEpochYield(_maxEpochYield1);
    }

    /**
     * Checks the distribution formula runs as expected when changing max yield.
     */
    function test_CanSetMaxEpochYieldRedistribution() external {
        // Make a deposit of 70 ether into the strategy as we will need to test that the
        // amount is reallocated correctly.
        vm.startPrank(testUser);
        IERC20(WETH).approve(address(strategy), 70 ether);
        strategy.depositErc20(70 ether);
        vm.stopPrank();

        // Confirm the starting yield split
        assertEq(strategy.epochYield(0), 20 ether);
        assertEq(strategy.epochYield(1), 20 ether);
        assertEq(strategy.epochYield(2), 20 ether);
        assertEq(strategy.epochYield(3), 10 ether);

        // Update our epoch yield and confirm that the redistribution has been done correctly
        strategy.setMaxEpochYield(30 ether);

        assertEq(strategy.epochYield(0), 30 ether);
        assertEq(strategy.epochYield(1), 30 ether);
        assertEq(strategy.epochYield(2), 10 ether);
        assertEq(strategy.epochYield(3), 0);

        // Shift our epoch 1 forward and change the distribution
        setCurrentEpoch(address(epochManager), 1);

        // The change should revert as we will need to withdraw available yield first
        vm.expectRevert('Yield must be withdrawn');
        strategy.setMaxEpochYield(15 ether);

        // Withdraw the yield and try to run again
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector));
        strategy.setMaxEpochYield(15 ether);

        // Since we didn't withdraw any amount, we should just now bypass the initial epoch and
        // begin distributing from the current epoch.
        assertEq(strategy.epochYield(0), 0);
        assertEq(strategy.epochYield(1), 15 ether);
        assertEq(strategy.epochYield(2), 15 ether);
        assertEq(strategy.epochYield(3), 15 ether);
        assertEq(strategy.epochYield(4), 10 ether);
        assertEq(strategy.epochYield(5), 0 ether);

        // Shift forward 1; Withdraw; Redistribute
        setCurrentEpoch(address(epochManager), 2);
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector));
        strategy.setMaxEpochYield(20 ether);

        assertEq(strategy.epochYield(0), 0);
        assertEq(strategy.epochYield(1), 0);
        assertEq(strategy.epochYield(2), 20 ether);
        assertEq(strategy.epochYield(3), 20 ether);
        assertEq(strategy.epochYield(4), 10 ether);
        assertEq(strategy.epochYield(5), 0);

        // Update the max yield to the same value to confirm we don't change anything
        strategy.setMaxEpochYield(20 ether);

        assertEq(strategy.epochYield(0), 0);
        assertEq(strategy.epochYield(1), 0);
        assertEq(strategy.epochYield(2), 20 ether);
        assertEq(strategy.epochYield(3), 20 ether);
        assertEq(strategy.epochYield(4), 10 ether);
        assertEq(strategy.epochYield(5), 0);

        // Update the max yield to all include in the same
        strategy.setMaxEpochYield(100 ether);
        assertEq(strategy.epochYield(0), 0 ether);
        assertEq(strategy.epochYield(1), 0 ether);
        assertEq(strategy.epochYield(2), 100 ether);
        assertEq(strategy.epochYield(3), 0 ether);
    }
}
