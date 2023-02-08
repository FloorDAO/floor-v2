// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../../src/contracts/tokens/Floor.sol';
import '../../src/contracts/staking/VeFloorStaking.sol';

import '../utilities/Environments.sol';

contract VeFloorStakingTest is FloorTest {

    // Test users
    address alice;

    // Internal contract references
    FLOOR floor;
    VeFloorStaking veFloor;

    constructor () {
        // Map our test user(s)
        alice = users[0];

        // Deploy our floor token
        floor = new FLOOR(address(authorityRegistry));

        // Deploy our staking contract with our test contract as the recipient of fees
        veFloor = new VeFloorStaking(floor, STAKING_EXP_BASE, address(this));

        floor.mint(address(this), 100 ether);
        floor.approve(address(veFloor), 100 ether);

        // Give Alice some FLOOR that will have permissions to go into the staking contract
        floor.mint(address(alice), 100 ether);
        vm.prank(alice);
        floor.approve(address(veFloor), 100 ether);

        // Set our max loss ratio as 10%
        veFloor.setMaxLossRatio(100000000);
    }

    function test_ShouldTakeUsersDeposit() external {
        (, , uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);

        veFloor.deposit(100 ether, 30 days);

        _assertBalances(address(this), 100 ether, 30 days);
    }

    function test_ShouldTakeUsersDepositForOtherAccount() external {
        (, , uint amount) = veFloor.depositors(alice);
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(alice), 0);
        assertEq(veFloor.votingPowerOf(alice), 0);

        uint balanceaddr = floor.balanceOf(address(this));
        uint balanceAddr1 = floor.balanceOf(alice);

        vm.prank(alice);
        veFloor.deposit(0, 30 days + 1);
        veFloor.depositFor(alice, 100 ether);

        assertEq(floor.balanceOf(address(this)), balanceaddr - 100 ether);
        assertEq(floor.balanceOf(alice), balanceAddr1);

        _assertBalances(alice, 100 ether, 30 days);

        (, , amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);
    }

    function test_ShouldIncreaseUnlockTimeForDeposit() external {
        veFloor.deposit(100 ether, 30 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime);

        veFloor.deposit(0, 730 days);
        _assertBalances(address(this), 100 ether, 730 days);
    }

    function test_ShouldDecreaseUnlockTimeWithEarlyWithdraw() external {
        veFloor.setMaxLossRatio(1000000000); // 100%
        veFloor.setFeeReceiver(address(this));

        veFloor.deposit(100 ether, 60 days);
        skip(5 days);

        veFloor.earlyWithdrawTo(address(this), 0 ether, 100 ether);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        assertEq(unlockTime, block.timestamp);
        floor.approve(address(veFloor), 100 ether);

        veFloor.deposit(100 ether, 30 days);

        _assertBalances(address(this), 100 ether, 30 days);
    }

    function test_ShouldIncreaseUnlockTimeForDepositWithReducedDuration() external {
        veFloor.deposit(70 ether, 30 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime);

        veFloor.deposit(0, 40 days);
        _assertBalances(address(this), 70 ether, 40 days);
    }

    function test_ShouldIncreaseDepositAmount() external {
        veFloor.deposit(20 ether, 50 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime - 45 days);

        veFloor.deposit(30 ether, 0);
        _assertBalances(address(this), 50 ether, unlockTime - (block.timestamp));
    }

    function test_CallDepositWithOneYearLockAndCompareVotingPowerAgainstExpectedValue() external {
        uint origin = veFloor.origin();
        veFloor.deposit(1 ether, 365 days);
        assertAlmostEqual(
            veFloor.votingPowerOfAt(address(this), origin),
            0.22360 ether,
            1e4
        );
    }

    function test_CallDepositWithTwoYearLockAndCompareVotingPowerAgainstExpectedValue() external {
        uint origin = veFloor.origin();
        veFloor.deposit(1 ether, 730 days);
        assertAlmostEqual(
            veFloor.votingPowerOfAt(address(this), origin),
            1 ether,
            1e4
        );
    }

    function test_CallDepositWithOneYearLockAndCompareVotingPowerAgainstExpectedValueAfterTheLockEnd() external {
        veFloor.deposit(1 ether, 365 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        assertAlmostEqual(
            veFloor.votingPowerOfAt(address(this), unlockTime),
            0.05 ether,
            1e4
        );
    }

    function test_CallDepositWithTwoYearLockAndCompareVotingPowerAgainstExpectedValueAfterTheLockEnd() external {
        veFloor.deposit(1 ether, 730 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        assertAlmostEqual(
            veFloor.votingPowerOfAt(address(this), unlockTime),
            0.05 ether,
            1e4
        );
    }

    function test_ShouldIncreaseDepositAmountForReducedDuration() external {
        veFloor.deposit(70 ether, 100 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime - 50 days);

        veFloor.deposit(20 ether, 0);
        _assertBalances(address(this), 90 ether, unlockTime - (block.timestamp));
    }

    function test_ShouldWithdrawUsersDeposit() external {
        veFloor.deposit(100 ether, 50 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime);
        uint balanceaddr = floor.balanceOf(address(this));

        veFloor.withdraw();

        assertEq(floor.balanceOf(address(this)), balanceaddr + 100 ether);

        (, , uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);
    }

    function test_ShouldStoreUnlockTimeAfterWithdraw() external {
        veFloor.deposit(100 ether, 50 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime);

        veFloor.withdraw();

        (, unlockTime, ) = veFloor.depositors(address(this));
        assertEq(unlockTime, block.timestamp);
    }

    function test_ShouldWithdrawUsersDepositAndSentTokensToOtherAddress() external {
        veFloor.deposit(100 ether, 50 days);

        (, uint unlockTime, ) = veFloor.depositors(address(this));
        vm.warp(unlockTime);

        uint balanceaddr = floor.balanceOf(address(this));
        uint balanceAddr1 = floor.balanceOf(alice);

        veFloor.withdrawTo(alice);

        assertEq(floor.balanceOf(address(this)), balanceaddr);
        assertEq(floor.balanceOf(alice), balanceAddr1 + 100 ether);

        (, , uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);
    }

    function test_ShouldNotTakeDepositWithLockLessThatMinimum() external {
        uint MIN_LOCK_PERIOD = veFloor.MIN_LOCK_PERIOD();

        vm.expectRevert(VeFloorStaking.LockTimeLessMinLock.selector);
        veFloor.deposit(50 ether, MIN_LOCK_PERIOD - 1);
    }

    function test_ShouldNotTakeDepositWithLockMoreThanMaximum() external {
        uint MAX_LOCK_PERIOD = veFloor.MAX_LOCK_PERIOD();

        vm.expectRevert(VeFloorStaking.LockTimeMoreMaxLock.selector);
        veFloor.deposit(50 ether, MAX_LOCK_PERIOD + 1);
    }

    function test_ShouldWithdrawBeforeUnlockTime() external {
        veFloor.deposit(50 ether, 30 days);

        vm.expectRevert(VeFloorStaking.UnlockTimeHasNotCome.selector);
        veFloor.withdraw();
    }

    function test_ShouldEmergencyWithdraw() external {
        veFloor.deposit(50 ether, 30 days);
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
        uint lockTime = 365 days;
        veFloor.deposit(1 ether, lockTime);
        skip(lockTime);

        vm.expectRevert(VeFloorStaking.StakeUnlocked.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenEmergencyExitIsSet() external {
        veFloor.deposit(1 ether, 365 days);
        veFloor.setEmergencyExit(true);

        vm.expectRevert(VeFloorStaking.StakeUnlocked.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenMinReturnIsNotMet() external {
        veFloor.deposit(1 ether, 365 days);

        vm.expectRevert(VeFloorStaking.MinReturnIsNotMet.selector);
        veFloor.earlyWithdrawTo(address(this), 1 ether, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenMaxLossIsNotMet() external {
        veFloor.deposit(1 ether, 365 days);

        vm.expectRevert(VeFloorStaking.MaxLossIsNotMet.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenLossIsTooBig() external {
        veFloor.deposit(1 ether, 730 days);

        vm.expectRevert(VeFloorStaking.LossIsTooBig.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1 ether);
    }

    function test_EarlyWithdrawToShouldWithdrawWithLoss() external {
        uint lockTime = 365 days;
        veFloor.deposit(1 ether, lockTime);

        skip(lockTime / 2);

        veFloor.setFeeReceiver(alice);

        (, , uint amount) = veFloor.depositors(address(this));
        uint vp = veFloor.votingPower(veFloor.balanceOf(address(this)));
        uint ret = (amount - vp) * 100 / 95;
        uint loss = amount - ret;

        uint balanceAddrBefore = floor.balanceOf(address(this));
        uint balanceAddr1Before = floor.balanceOf(alice);

        veFloor.earlyWithdrawTo(address(this), 1, 0.2 ether);
        assertEq(floor.balanceOf(alice), balanceAddr1Before + loss);
        assertEq(floor.balanceOf(address(this)), balanceAddrBefore + 1 ether - loss);
    }

    function test_EarlyWithdrawToShouldDecreaseLossWithTime() external {
        uint lockTime = 730 days;
        veFloor.deposit(1 ether, lockTime);
        uint stakedTime = block.timestamp;

        (uint rest2YearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        vm.warp(stakedTime + 182 days);
        (uint rest1HalfYearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        vm.warp(stakedTime + 365 days);
        (uint rest1YearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        vm.warp(stakedTime + 547 days);
        (uint restHalfYearsLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        vm.warp(stakedTime + 365 days + 48 weeks);
        (uint restMonthLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        vm.warp(stakedTime + 365 days + 51 weeks);
        (uint restWeekLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        vm.warp(stakedTime + 365 days + 364 days);
        (uint restDayLoss,,) = veFloor.earlyWithdrawLoss(address(this));

        assertGt(rest2YearsLoss, rest1HalfYearsLoss);
        assertGt(rest1HalfYearsLoss, rest1YearsLoss);
        assertGt(rest1YearsLoss, restHalfYearsLoss);
        assertGt(restHalfYearsLoss, restMonthLoss);
        assertGt(restMonthLoss, restWeekLoss);
        assertGt(restWeekLoss, restDayLoss);
    }

    function test_CanExemptCallerFromEarlyWithdrawFees() external {
        uint lockTime = 365 days;
        veFloor.deposit(1 ether, lockTime);

        skip(lockTime / 2);

        veFloor.setFeeReceiver(alice);
        veFloor.addEarlyWithdrawFeeExemption(address(this), true);

        uint balanceAddrBefore = floor.balanceOf(address(this));
        uint balanceAddr1Before = floor.balanceOf(alice);

        veFloor.earlyWithdrawTo(address(this), 1, 0.2 ether);

        // Confirm that no fees were sent to our receiver
        assertEq(floor.balanceOf(alice), balanceAddr1Before);

        // Confirm that our recipient received the correct amount of token back
        assertAlmostEqual(floor.balanceOf(address(this)), balanceAddrBefore + 1 ether, 1e4);
    }

    function _assertBalances(address account, uint balance, uint /* c */) internal {
        (uint unlockTime,, uint amount) = veFloor.depositors(account);
        assertEq(amount, balance);
        assertAlmostEqual(
            veFloor.votingPowerOfAt(account, unlockTime),
            balance / 20,
            1e10
        );
    }

}
