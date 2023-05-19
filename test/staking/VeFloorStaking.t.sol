// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract VeFloorStakingTest is FloorTest {
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
        veFloor.deposit(100 ether, 6);

        // Confirm that we should have the full balance available at 0 epoch
        assertEq(veFloor.votingPowerAt(address(this), 0), 100 ether);

        // Confirm that half way through (epoch 52) we have half the power
        assertEq(veFloor.votingPowerAt(address(this), 52), 50 ether);

        // Confirm that we should have 0 balance at 104 epoch
        assertEq(veFloor.votingPowerAt(address(this), 104), 0 ether);
    }

    function test_ShouldTakeUsersDepositForOtherAccount() external {
        (,, uint amount) = veFloor.depositors(alice);
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(alice), 0);
        assertEq(veFloor.votingPowerOf(alice), 0);

        uint balanceaddr = floor.balanceOf(address(this));
        uint balanceAddr1 = floor.balanceOf(alice);

        // TODO: Is this right?
        vm.prank(alice);
        veFloor.deposit(0, 6);

        veFloor.depositFor(alice, 100 ether);

        assertEq(floor.balanceOf(address(this)), balanceaddr - 100 ether);
        assertEq(floor.balanceOf(alice), balanceAddr1);

        _assertBalances(alice, 100 ether, 0);

        (,, amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);
    }

    function test_ShouldIncreaseUnlockTimeForDeposit() external {
        veFloor.deposit(100 ether, 1);

        epochManager.setCurrentEpoch(2);

        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 4);
        assertEq(amount, 100 ether);

        assertEq(veFloor.votingPowerOf(address(this)), 1923076923076923076);

        veFloor.deposit(0, 6);

        (epochStart, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 2);
        assertEq(epochCount, 104);
        assertEq(amount, 100 ether);

        assertEq(veFloor.votingPowerOf(address(this)), 100 ether);
    }

    function test_ShouldDecreaseUnlockTimeWithEarlyWithdraw() external {
        veFloor.setMaxLossRatio(1000000000); // 100%
        veFloor.setFeeReceiver(address(this));

        veFloor.deposit(100 ether, 2);
        epochManager.setCurrentEpoch(6);

        veFloor.earlyWithdrawTo(address(this), 0 ether, 100 ether);

        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 13);
        assertEq(amount, 0 ether);

        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 1);

        (epochStart, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 6);
        assertEq(epochCount, 4);
        assertEq(amount, 100 ether);
    }

    function test_ShouldIncreaseDepositAmount() external {
        // Deposit with a 52 epoch lock
        veFloor.deposit(20 ether, 4);

        // Set our epoch to half way through the lock
        epochManager.setCurrentEpoch(26);

        // Deposit 30 ether with no epoch specified
        veFloor.deposit(30 ether, 0);

        // This should give our user 50 ether amount, but still ending at the same time
        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 52);
        assertEq(amount, 50 ether);
        assertEq(veFloor.votingPowerOf(address(this)), 12.5 ether);
    }

    function test_CallDepositWithOneYearLockAndCompareVotingPowerAgainstExpectedValueAfterTheLockEnd() external {
        veFloor.deposit(1 ether, 4);

        assertEq(veFloor.votingPowerAt(address(this), 52), 0);
        assertEq(veFloor.votingPowerAt(address(this), 53), 0);
        assertEq(veFloor.votingPowerAt(address(this), 104), 0);
    }

    function test_CallDepositWithTwoYearLockAndCompareVotingPowerAgainstExpectedValueAfterTheLockEnd() external {
        veFloor.deposit(1 ether, 6);

        assertEq(veFloor.votingPowerAt(address(this), 104), 0);
        assertEq(veFloor.votingPowerAt(address(this), 105), 0);
        assertEq(veFloor.votingPowerAt(address(this), 208), 0);
    }

    function test_ShouldReturnZeroBeforeDepositMade() external {
        epochManager.setCurrentEpoch(1);

        veFloor.deposit(1 ether, 6);

        assertEq(veFloor.votingPowerAt(address(this), 0), 0);
    }

    function test_ShouldIncreaseDepositAmountForReducedDuration() external {
        // Deposit 70 tokens for 52 epochs
        veFloor.deposit(70 ether, 4);

        // Get our epoch end by taking the `epochStart` and the `epochCount`
        epochManager.setCurrentEpoch(26);

        // Deposit an additional 20 tokens with no time increase
        veFloor.deposit(20 ether, 0);

        // Confirm our depositor information is as expected
        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 52);
        assertEq(amount, 90 ether);

        assertEq(veFloor.votingPowerOf(address(this)), 22.5 ether);
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
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenLossIsTooBig() external {
        // Set our max loss ratio as 10% (9 decimal accuracy)
        veFloor.setMaxLossRatio(1_00000000);

        veFloor.deposit(1 ether, 5);

        vm.expectRevert(VeFloorStaking.LossIsTooBig.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1 ether);
    }

    function test_EarlyWithdrawToShouldWithdrawWithLoss() external {
        // Deposit with a 52 week lock
        veFloor.deposit(1 ether, 4);

        // Move our epoch forward to 26 weeks
        epochManager.setCurrentEpoch(48);

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
        veFloor.deposit(1 ether, 6);

        (uint rest2YearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(26);
        (uint rest1HalfYearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(52);
        (uint rest1YearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(78);
        (uint restHalfYearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(100);
        (uint restMonthLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(102);
        (uint restWeekLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        epochManager.setCurrentEpoch(103);
        (uint restDayLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        assertGt(rest2YearsLoss, rest1HalfYearsLoss);
        assertGt(rest1HalfYearsLoss, rest1YearsLoss);
        assertGt(rest1YearsLoss, restHalfYearsLoss);
        assertGt(restHalfYearsLoss, restMonthLoss);
        assertGt(restMonthLoss, restWeekLoss);
        assertGt(restWeekLoss, restDayLoss);
    }

    function test_CanExemptCallerFromEarlyWithdrawFees() external {
        // Lock 1 token for 52 weeks
        veFloor.deposit(1 ether, 4);

        // Shift our epoch to 26 weeks
        epochManager.setCurrentEpoch(26);

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
        veFloor.deposit(100 ether, 6);

        epochManager.setCurrentEpoch(0);
        (uint loss, uint ret, bool canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 50 ether);
        assertEq(ret, 50 ether);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(26);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 37.5 ether); // 28125000000000000000
        assertEq(ret, 62.5 ether);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(52);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 25 ether);
        assertEq(ret, 75 ether);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(78);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 12.5 ether);
        assertEq(ret, 87.5 ether);
        assertEq(canWithdraw, true);

        epochManager.setCurrentEpoch(104);
        (loss, ret, canWithdraw) = veFloor.earlyWithdrawLoss(address(this));
        assertEq(loss, 0 ether);
        assertEq(ret, 100 ether);
        assertEq(canWithdraw, true);
    }

    function _assertBalances(address _account, uint _balance, uint _epoch) internal {
        // (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(_account);
        assertEq(veFloor.votingPowerAt(_account, _epoch), _balance);
    }
}
