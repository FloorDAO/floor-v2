// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract VeFloorStakingTest is FloorTest {
    // Store our max epoch index
    uint internal constant MAX_EPOCH_INDEX = 3;

    // Allow for early withdraw inaccuracy
    uint internal constant MAX_EARLY_WITHDRAW_INACCURACY = 20;

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

    function test_ShouldTakeUsersDeposit(uint _amount, uint8 _lockPeriod) external {
        vm.assume(_amount > 0);
        vm.assume(_amount <= 100 ether);

        vm.assume(_lockPeriod < MAX_EPOCH_INDEX);

        (,, uint amount) = veFloor.depositors(address(this));
        assertEq(amount, 0);
        assertEq(veFloor.balanceOf(address(this)), 0);
        assertEq(veFloor.votingPowerOf(address(this)), 0);

        // Deposit at the max index of the lock period (104 epochs)
        veFloor.deposit(_amount, _lockPeriod);

        // Confirm that we should have the full balance available
        assertEq(
            veFloor.votingPowerOf(address(this)),
            _amount * veFloor.LOCK_PERIODS(_lockPeriod) / veFloor.LOCK_PERIODS(MAX_EPOCH_INDEX)
        );
    }

    function test_ShouldIncreaseUnlockTimeForDeposit(uint128 initialAmount, uint128 topupAmount) external {
        // Ensure that our initial amount is a value we can calculate power from
        vm.assume(initialAmount > 1 ether);

        // Ensure that the combination of our two values won't overflow
        vm.assume(uint(initialAmount) + topupAmount < 100 ether);

        // Deposit our initial
        veFloor.deposit(initialAmount, 2);

        setCurrentEpoch(address(epochManager), 2);

        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 8);
        assertEq(amount, initialAmount);

        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(initialAmount));

        veFloor.deposit(topupAmount, MAX_EPOCH_INDEX);

        (epochStart, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 2);
        assertEq(epochCount, 12);
        assertEq(amount, initialAmount + topupAmount);
        assertEq(veFloor.votingPowerOf(address(this)), initialAmount + topupAmount);
    }

    function test_ShouldDecreaseUnlockTimeWithEarlyWithdraw() external {
        veFloor.setMaxLossRatio(1000000000); // 100%
        veFloor.setFeeReceiver(address(this));

        // Get our initial FLOOR token holding
        uint floorBalance = floor.balanceOf(address(this));

        // Deposit for 8 epochs
        veFloor.deposit(100 ether, 2);

        // Confirm that our balance has increased by 100 ether
        assertEq(floor.balanceOf(address(this)), floorBalance - 100 ether);

        setCurrentEpoch(address(epochManager), 2);

        veFloor.earlyWithdrawTo(address(this), 0 ether, 100 ether);

        // Checking the amount received is correct.
        assertEq(floor.balanceOf(address(this)), floorBalance);

        (uint160 epochStart, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 0);
        assertEq(epochCount, 0);
        assertEq(amount, 0 ether);

        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 2);

        (epochStart, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(epochStart, 2);
        assertEq(epochCount, 8);
        assertEq(amount, 100 ether);
    }

    function test_ShouldReturnZeroBeforeDepositMade() external {
        setCurrentEpoch(address(epochManager), 1);

        assertEq(veFloor.votingPowerOf(address(this)), 0);

        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        assertEq(veFloor.votingPowerOf(address(this)), 1 ether);
    }

    function test_ShouldWithdrawUsersDeposit() external {
        veFloor.deposit(100 ether, 1);

        setCurrentEpoch(address(epochManager), 4);

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

        setCurrentEpoch(address(epochManager), 4);

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
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX - 1);
        setCurrentEpoch(address(epochManager), 26);

        vm.expectRevert(VeFloorStaking.StakeUnlocked.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenEmergencyExitIsSet() external {
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX - 1);
        veFloor.setEmergencyExit(true);

        vm.expectRevert(VeFloorStaking.StakeUnlocked.selector);
        veFloor.earlyWithdrawTo(address(this), 1, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenMinReturnIsNotMet() external {
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX - 1);

        vm.expectRevert(VeFloorStaking.MinReturnIsNotMet.selector);
        veFloor.earlyWithdrawTo(address(this), 1 ether, 1);
    }

    function test_EarlyWithdrawToShouldNotWorkWhenMaxLossIsNotMet() external {
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX - 1);

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
        setCurrentEpoch(address(epochManager), 10);

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

    function test_EarlyWithdrawToShouldDecreaseLossWithTime(uint _deposit) external {
        vm.assume(_deposit >= 1 ether);
        vm.assume(_deposit <= 100 ether);

        veFloor.deposit(_deposit, MAX_EPOCH_INDEX);

        // Loop through all possible epoch locks, ensuring that the upper value will
        // always be within range. We then compare that the loss from the later epoch
        // will always be less than the former epoch.
        for (uint i; i < 12; ++i) {
            setCurrentEpoch(address(epochManager), i);
            (uint a,,) = veFloor.earlyWithdrawLoss(address(this));

            setCurrentEpoch(address(epochManager), i + 1);
            (uint b,,) = veFloor.earlyWithdrawLoss(address(this));

            assertLt(b, a);
        }
    }

    function test_CanExemptCallerFromEarlyWithdrawFees() external {
        // Lock 1 token for 24 weeks
        veFloor.deposit(1 ether, MAX_EPOCH_INDEX);

        // Shift our epoch to 12 weeks
        setCurrentEpoch(address(epochManager), 6);

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

    function _testEarlyWithdrawLoss(uint _epoch, uint _loss, uint _ret, bool _canWithdraw) internal {
        setCurrentEpoch(address(epochManager), _epoch);
        (uint loss, uint ret, bool canWithdraw) = veFloor.earlyWithdrawLoss(address(this));

        if (_loss != 0) {
            assertAlmostEqual(loss, _loss, MAX_EARLY_WITHDRAW_INACCURACY);
        } else {
            assertEq(loss, _loss);
        }

        if (_ret != 0) {
            assertAlmostEqual(ret, _ret, MAX_EARLY_WITHDRAW_INACCURACY);
        } else {
            assertEq(ret, _ret);
        }

        assertEq(canWithdraw, _canWithdraw);
    }

    function test_CanDetermineEarlyWithdrawLossAtFullStakeDuration(uint _deposit) external {
        // Set a range that would offer a reasonable deposit and below the user balance
        vm.assume(_deposit >= 1 ether);
        vm.assume(_deposit <= 100 ether);

        veFloor.deposit(_deposit, MAX_EPOCH_INDEX);

        // After no epochs have passed, all funds should be lost
        _testEarlyWithdrawLoss(0, _deposit, 0, true);

        // Loop through all epochs between point of lock and point of completion
        for (uint i = 1; i < 12; ++i) {
            _testEarlyWithdrawLoss(i, _deposit * (12 - i) / 12, _deposit * i / 12, true);
        }

        // At lock expiry, and subsequent epochs, we should have nothing lost and the
        // full deposit available.
        for (uint i = 12; i < 24; ++i) {
            _testEarlyWithdrawLoss(i, 0, _deposit, true);
        }
    }

    function test_CanDetermineEarlyWithdrawLossAtPartialStakeDuration(uint _deposit) external {
        // Set a range that would offer a reasonable deposit and below the user balance
        vm.assume(_deposit >= 1 ether);
        vm.assume(_deposit <= 100 ether);

        veFloor.deposit(_deposit, MAX_EPOCH_INDEX - 1);

        _testEarlyWithdrawLoss(0, _deposit / 2, _deposit / 2, true);

        for (uint i; i < 8; ++i) {
            _testEarlyWithdrawLoss(i, (_deposit / 2) * (12 - i) / 12, (_deposit / 2) + (_deposit * i / 12), true);
        }

        // At lock expiry, and subsequent epochs, we should have nothing lost and the
        // full deposit available.
        for (uint i = 8; i < 16; ++i) {
            _testEarlyWithdrawLoss(i, 0, _deposit, true);
        }
    }

    // Example 1 : Lock for 8 epochs, call refresh with 0 epochs passed. Should not change.
    function test_CanRefreshLock_1(uint160 _startEpoch) external {
        // Set our current epoch to our test value
        setCurrentEpoch(address(epochManager), _startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 2);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));
    }

    // Example 2 : Lock for 8 epochs, call refresh with less than 8 epochs passed. Should not change.
    function test_CanRefreshLock_2(uint160 _startEpoch, uint8 _epochShift) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - 8);

        // Test for all values under the lock limit
        vm.assume(_epochShift < 8);

        // Set our current epoch to our test value
        setCurrentEpoch(address(epochManager), _startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 2);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));

        // Move our epoch forward after the deposit
        setCurrentEpoch(address(epochManager), _startEpoch + _epochShift);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        uint expectedStartEpoch = (_epochShift == 7) ? _startEpoch + 1 : _startEpoch;

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, expectedStartEpoch);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));
    }

    // Example 3 : Lock for 8 epochs, call refresh with 8 epochs passed. Should change.
    function test_CanRefreshLock_3(uint160 _startEpoch) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - 8);

        // Set our current epoch to our test value
        setCurrentEpoch(address(epochManager), _startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 2);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));

        // Move our epoch forward after the deposit
        setCurrentEpoch(address(epochManager), _startEpoch + 8);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, epochManager.currentEpoch() - 6);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));
    }

    // Example 4 : Lock for 8 epochs, call refresh with more than 8 epochs passed. Should change.
    function test_CanRefreshLock_4(uint160 _startEpoch, uint8 _epochShift) external {
        // Ensure we don't get value overflow for our starting epoch
        vm.assume(_startEpoch < type(uint160).max - type(uint8).max);

        // Ensure we shift more than 8 epochs, but not over the uint160 cap
        vm.assume(_epochShift > 8);

        // Set our current epoch to our test value
        setCurrentEpoch(address(epochManager), _startEpoch);

        // Set our voting contracts. The actual address does not matter, as we only need to
        // use it to prank the caller.
        veFloor.setVotingContracts(address(1), address(2));

        veFloor.deposit(1 ether, 2);
        (uint160 startEpoch, uint8 epochCount, uint88 amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, _startEpoch);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));

        // Move our epoch forward after the deposit
        setCurrentEpoch(address(epochManager), _startEpoch + _epochShift);

        vm.prank(address(1));
        veFloor.refreshLock(address(this));

        (startEpoch, epochCount, amount) = veFloor.depositors(address(this));
        assertEq(startEpoch, epochManager.currentEpoch() - 6);
        assertEq(epochCount, 8);
        assertEq(amount, 1 ether);
        assertEq(veFloor.votingPowerOf(address(this)), _calculateTwoThirds(1 ether));
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

    /**
     * Tests that a user can deposit for a second time, as long as the duration of the total
     * staking period is the same or greater.
     *
     * This means that a user can stake for a shorter amount of time, as long as the ending
     * lock time is greater or equal that the existing one.
     */
    function test_CanDepositTwiceAsLongAsNewDurationIsGreaterOrEqualToRemaining(
        uint8 firstIndex,
        uint8 secondIndex,
        uint128 _startEpoch,
        uint128 _intermediaryEpoch
    ) public {
        // Map our epochs to uint
        uint startEpoch = uint(_startEpoch);
        uint intermediaryEpoch = uint(_intermediaryEpoch);

        // Set our expected index range
        vm.assume(firstIndex <= MAX_EPOCH_INDEX);
        vm.assume(secondIndex <= MAX_EPOCH_INDEX);

        // Ensure our intermediary is >= the start epoch
        vm.assume(intermediaryEpoch >= startEpoch);

        // Set our initial epoch
        setCurrentEpoch(address(epochManager), startEpoch);

        // Make an initial deposit of a set index
        veFloor.deposit(10 ether, firstIndex);

        // Update the current epoch
        setCurrentEpoch(address(epochManager), intermediaryEpoch);

        // Determine if this second deposit should fail
        if (startEpoch + veFloor.LOCK_PERIODS(firstIndex) > intermediaryEpoch + veFloor.LOCK_PERIODS(secondIndex)) {
            vm.expectRevert('Cannot stake less epochs');
        }

        // Make another deposit of another set index
        veFloor.deposit(10 ether, secondIndex);
    }

    function _calculateTwoThirds(uint i) internal pure returns (uint) {
        return i * 2 / 3;
    }
}
