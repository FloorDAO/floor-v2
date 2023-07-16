// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract VeFloorStakingTest is FloorTest {
    // Store our max epoch index
    uint internal constant MAX_EPOCH_INDEX = 4;

    // Test users
    address alice;

    // Internal contract references
    EpochManager epochManager;
    FLOOR floor;
    VeFloorStaking veFloor;

    constructor() {
        // Map our test user(s)
        alice = users[0];

        // Deploy our floor token
        floor = new FLOOR(address(authorityRegistry));

        // Deploy our staking contract with our test contract as the recipient of fees
        veFloor = new VeFloorStaking(floor, address(this));

        // Create our {EpochManager} contract and assign it to {VeFloorStaking}
        epochManager = new EpochManager();
        veFloor.setEpochManager(address(epochManager));

        floor.mint(address(this), 100 ether);
        floor.approve(address(veFloor), 100 ether);

        // Give Alice some FLOOR that will have permissions to go into the staking contract
        floor.mint(address(alice), 100 ether);
        vm.prank(alice);
        floor.approve(address(veFloor), 100 ether);

        // Set our max loss ratio as 100% (9 decimal accuracy)
        veFloor.setMaxLossRatio(1_000000000);
    }

    function test_ShouldTakeUsersDeposit() external {
        (,, uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);

        // Deposit at the max index of the lock period (104 epochs)
        veFloor.deposit(100 ether, MAX_EPOCH_INDEX);

        // Confirm that we should have the full balance available at 0 epoch
        assertEq(veFloor.votingPowerAt(address(this), 0), 100 ether);

        // Confirm that half way through (epoch 52) we still have half full power
        assertEq(veFloor.votingPowerAt(address(this), 4), 100 ether);

        // Confirm that we should still have a full power balance at 104 epoch
        assertEq(veFloor.votingPowerAt(address(this), 104), 100 ether);
    }

    function test_ShouldIncreaseUnlockTimeForDeposit() external {
        veFloor.deposit(100 ether, 3);

        epochManager.setCurrentEpoch(2);

        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 12);
        assertEq(amount, 100 ether);

        assertEq(veFloor.votingPowerOf(address(this)), 50 ether);

        veFloor.deposit(0, MAX_EPOCH_INDEX);
        /// Audit Note - May be good to check with non zero here to ensure amount goes up

        (epochStart, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 2);
        assertEq(epochCount, 24);
        assertEq(amount, 100 ether);

        assertEq(veFloor.votingPowerOf(address(this)), 100 ether);
    }

    function test_ShouldDecreaseUnlockTimeWithEarlyWithdraw() external {
        veFloor.setMaxLossRatio(1000000000); // 100%
        veFloor.setFeeReceiver(address(this));

        // Deposit for 8 epochs
        veFloor.deposit(100 ether, 2);
        epochManager.setCurrentEpoch(2);

        veFloor.earlyWithdrawTo(address(this), 0 ether, 100 ether);
        /// Audit Note - Should be checking the amount received is correct.

        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        /// Audit Note - Not deleting the epoc count on withdraw is interesting, and could create
        ///              weird issues. IE: user A deposit for 24 weeks and then withdraws and comes back later
        //               their address cannot deposit for less than 24 weeks.
        assertEq(epochCount, 8);
        assertEq(amount, 0 ether);

        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 2);

        (epochStart, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 2);
        assertEq(epochCount, 8);
        assertEq(amount, 100 ether);
    }

    function test_CallDepositWithOneYearLockAndCompareVotingPowerAgainstExpectedValueAfterTheLockEnd() external {
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        assertEq(veFloor.votingPowerAt(address(this), 24), 1 ether);
        assertEq(veFloor.votingPowerAt(address(this), 25), 1 ether);
        assertEq(veFloor.votingPowerAt(address(this), 48), 1 ether);
    }

    function test_CallDepositWithTwoYearLockAndCompareVotingPowerAgainstExpectedValueAfterTheLockEnd() external {
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        assertEq(veFloor.votingPowerAt(address(this), 104), 1 ether);
        assertEq(veFloor.votingPowerAt(address(this), 105), 1 ether);
        assertEq(veFloor.votingPowerAt(address(this), 208), 1 ether);
    }

    function test_ShouldReturnZeroBeforeDepositMade() external {
        epochManager.setCurrentEpoch(1);

        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        assertEq(veFloor.votingPowerAt(address(this), 0), 0);
    }

    function test_ShouldWithdrawUsersDeposit() external {
        veFloor.deposit(100 ether, 1);

        epochManager.setCurrentEpoch(4);

        uint balanceaddr = floor.balanceOf(address(this));

        veFloor.withdraw();

        assertEq(floor.balanceOf(address(this)), balanceaddr + 100 ether);

        (,, uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);
    }

    function test_ShouldWithdrawUsersDepositAndSentTokensToOtherAddress() external {
        veFloor.deposit(100 ether, 1);

        epochManager.setCurrentEpoch(4);

        uint balanceaddr = floor.balanceOf(address(this));
        uint balanceAddr1 = floor.balanceOf(alice);

        veFloor.withdrawTo(alice);

        assertEq(floor.balanceOf(address(this)), balanceaddr);
        assertEq(floor.balanceOf(alice), balanceAddr1 + 100 ether);

        (,, uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);

        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);
    }

    function test_ShouldNotTakeDepositWithLockMoreThanMaximum() external {
        vm.expectRevert('Invalid epoch index');
        veFloor.deposit(50 ether, 7);
    }

    function test_ShouldWithdrawBeforeUnlockTime() external {
        veFloor.deposit(50 ether, 1);

        vm.expectRevert(VeFloorStaking.UnlockTimeHasNotCome.selector);
        veFloor.withdraw();
    }

    function test_ShouldEmergencyWithdraw() external {
        veFloor.deposit(50 ether, 1);
        uint balanceaddr = floor.balanceOf(address(this));
        assertEq(veFloor.emergencyExit(), false);

        veFloor.setEmergencyExit(true);
        veFloor.withdraw();

        assertEq(veFloor.emergencyExit(), true);
        assertEq(floor.balanceOf(address(this)), balanceaddr + 50 ether);
    }

    function test_ShouldNotSetEmergencyExitIfCallerIsNotTheOwner() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.startPrank(alice);
        veFloor.setEmergencyExit(true);
        vm.stopPrank();
    }

    function test_EarlyWithdrawToShouldNotWorkAfterUnlockTime() external {
        veFloor.deposit(1 ether, 3);
        epochManager.setCurrentEpoch(26);

        vm.expectRevert(VeFloorStaking.StakeUnlocked.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenEmergencyExitIsSet() external {
        veFloor.deposit(1 ether, 3);
        veFloor.setEmergencyExit(true);

        vm.expectRevert(VeFloorStaking.StakeUnlocked.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenMinReturnIsNotMet() external {
        veFloor.deposit(1 ether, 3);

        vm.expectRevert(VeFloorStaking.MinReturnIsNotMet.selector);
        veFloor.earlyWithdrawTo(address(this), 1 ether, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenMaxLossIsNotMet() external {
        veFloor.deposit(1 ether, 3);

        vm.expectRevert(VeFloorStaking.MaxLossIsNotMet.selector);
        veFloor.earlyWithdrawTo(address(this), 0, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenLossIsTooBig() external {
        // Set our max loss ratio as 10% (9 decimal accuracy)
        veFloor.setMaxLossRatio(1_00000000);

        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        vm.expectRevert(VeFloorStaking.LossIsTooBig.selector);
        veFloor.earlyWithdrawTo(address(this), 0, 1 ether);
    }

    function test_EarlyWithdrawToShouldWithdrawWithLoss() external {
        // Deposit with a 24 week lock
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        // Move our epoch forward to 20 weeks
        epochManager.setCurrentEpoch(20);

        // Set Alice to receive fees
        veFloor.setFeeReceiver(alice);

        // Calculate our returned amount and loss
        (uint loss,, bool canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertTrue(canWithdraw);

        // Store our pre-tx balances
        uint balanceAddrBefore = floor.balanceOf(address(this));
        uint balanceAddr1Before = floor.balanceOf(alice);

        // Withdraw early ensuring we get at least 1 wei, and lose at most 0.2 tokens
        veFloor.earlyWithdrawTo(address(this), 1, 0.2 ether);

        assertEq(floor.balanceOf(alice), balanceAddr1Before + loss);
        assertEq(floor.balanceOf(address(this)), balanceAddrBefore + 1 ether - loss);
    }

    function test_EarlyWithdrawToShouldDecreaseLossWithTime() external {
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        (uint rest2YearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(2);
        (uint rest1HalfYearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(4);
        (uint rest1YearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(8);
        (uint restHalfYearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(12);
        (uint restMonthLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(20);
        (uint restWeekLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(22);
        (uint restDayLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        assertGt(rest2YearsLoss, rest1HalfYearsLoss);
        assertGt(rest1HalfYearsLoss, rest1YearsLoss);
        assertGt(rest1YearsLoss, restHalfYearsLoss);
        assertGt(restHalfYearsLoss, restMonthLoss);
        assertGt(restMonthLoss, restWeekLoss);
        assertGt(restWeekLoss, restDayLoss);
    }

    function test_CanExemptCallerFromEarlyWithdrawFees() external {
        // Lock 1 token for 24 weeks
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        // Shift our epoch to 12 weeks
        epochManager.setCurrentEpoch(12);

        // Set Alice to receive fees
        veFloor.setFeeReceiver(alice);

        // Exempt this test from being charged fees
        veFloor.addEarlyWithdrawFeeExemption(address(this), true);

        // Store our pre-tx balances
        uint balanceAddrBefore = floor.balanceOf(address(this));
        uint balanceAddr1Before = floor.balanceOf(alice);

        // Withdraw early ensuring we get at least 1 wei, and lose at most 0.2 tokens
        veFloor.earlyWithdrawTo(address(this), 1, 0.2 ether);

        // Confirm that no fees were sent to our receiver
        assertEq(floor.balanceOf(alice), balanceAddr1Before);
        assertAlmostEqual(floor.balanceOf(address(this)), balanceAddrBefore + 1 ether, 1e4);
    }

    function test_CanDetermineEarlyWithdrawLoss() external {
        veFloor.deposit(100 ether, MAX_EPOCH_INDEX);

        epochManager.setCurrentEpoch(0);
        (uint loss, uint ret, bool canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 100 ether);
        assertEq(ret, 0 ether);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(2);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 91666666666666666667);
        assertEq(ret, 8333333333333333333);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(4);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 83333333333333333334);
        assertEq(ret, 16666666666666666666);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(8);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 66666666666666666667);
        assertEq(ret, 33333333333333333333);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(12);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 50 ether);
        assertEq(ret, 50 ether);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(24);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 0 ether);
        assertEq(ret, 100 ether);
        assertEq(canWithdraw, true);
    }

    // Example 1 : Lock for 12 epochs, call refresh with 0 epochs passed. Should not change.
    function test_CanRefreshLock_1(uint160 _startEpoch) external {
        // Set our current epoch to our test value
        epochManager.setCurrentEpoch(_startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 3);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);
    }

    // Example 2 : Lock for 12 epochs, call refresh with 10 epochs passed. Should not change.
    function test_CanRefreshLock_2(uint160 _startEpoch) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - 10);

        // Set our current epoch to our test value
        epochManager.setCurrentEpoch(_startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 3);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);

        // Move our epoch forward after the deposit
        epochManager.setCurrentEpoch(_startEpoch + 10);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);
    }

    // Example 3 : Lock for 12 epochs, call refresh with 11 epochs passed. Should change.
    function test_CanRefreshLock_3(uint160 _startEpoch) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - 11);

        // Set our current epoch to our test value
        epochManager.setCurrentEpoch(_startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 3);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);

        // Move our epoch forward after the deposit
        epochManager.setCurrentEpoch(_startEpoch + 11);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, epochManager.currentEpoch() - 10);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);
    }

    // Example 4 : Lock for 12 epochs, call refresh with 12 epochs passed. Should change.
    function test_CanRefreshLock_4(uint160 _startEpoch) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - 12);

        // Set our current epoch to our test value
        epochManager.setCurrentEpoch(_startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 3);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);

        // Move our epoch forward after the deposit
        epochManager.setCurrentEpoch(_startEpoch + 10);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, epochManager.currentEpoch() - 10);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);
    }

    // Example 5 : Lock for 12 epochs, call refresh with 24 epochs passed. Should change.
    function test_CanRefreshLock_5(uint160 _startEpoch) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - 24);

        // Set our current epoch to our test value
        epochManager.setCurrentEpoch(_startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 3);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);

        // Move our epoch forward after the deposit
        epochManager.setCurrentEpoch(_startEpoch + 24);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, epochManager.currentEpoch() - 10);
        assertEq(epochCount, 12);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 0.5 ether);
    }

    function test_CannotRefreshLockFromUnknownCaller(address caller) external {
        // Set our voting contracts to specific addresses
        veFloor.setVotingContracts(address(1), address(2));

        // Ensure that the caller is not one of the voting contracts that we defined
        vm.assume(caller != address(1));
        vm.assume(caller != address(2));

        // Prank call as the random address and confirm that it is reverted
        vm.prank(caller);
        vm.expectRevert('Invalid caller');
        veFloor.refreshLock(address(this));
    }

    function _assertBalances(address _account, uint _balance, uint _epoch) internal {
        // (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(_account);
        assertEq(veFloor.votingPowerAt(_account, _epoch), _balance);
    }
}
