// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../src/contracts/collections/CollectionRegistry.sol";
import "../../src/contracts/staking/VeFloorStaking.sol";
import "../../src/contracts/tokens/Floor.sol";
import "../../src/contracts/tokens/VeFloor.sol";
import {GaugeWeightVote} from "../../src/contracts/voting/GaugeWeightVote.sol";

import "../utilities/Environments.sol";

contract VeFloorStakingTest is FloorTest {
    // Contract mappings
    FLOOR floor;
    veFLOOR veFloor;
    GaugeWeightVote gaugeWeightVote;
    VeFloorStaking veFloorStaking;

    // Set our default values
    uint256 veFloorPerSharePerSec = 1 ether;
    uint256 speedUpVeFloorPerSharePerSec = 1 ether;
    uint256 speedUpThreshold = 5;
    uint256 speedUpDuration = 50;
    uint256 maxCapPct = 20000;

    // Store our test users that will be mapped to our users created
    // in the environment.
    address payable alice;
    address payable bob;
    address payable carol;

    constructor() {
        // Create our token contracts
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new veFLOOR('veFloor', 'veFLOOR', address(authorityRegistry));

        // ..
        CollectionRegistry collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Create our Gauge Weight Vote contract
        gaugeWeightVote = new GaugeWeightVote(
            address(collectionRegistry),
            address(this),  // Vault factory but not needed
            address(veFloor),
            address(authorityRegistry)
        );

        // Create our veFloor Staking contract
        veFloorStaking = new VeFloorStaking(
            address(authorityRegistry),
            floor,
            veFloor,
            gaugeWeightVote,
            veFloorPerSharePerSec,
            speedUpVeFloorPerSharePerSec,
            speedUpThreshold,
            speedUpDuration,
            maxCapPct
        );

        // Grant our {veFloorStaking} contract the authority to manage veFloor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(veFloorStaking));

        // We need to allow our {VeFloorStaking} contract to have {VOTE_MANAGER} permissions
        // so that we can trigger vote revoke calls.
        authorityRegistry.grantRole(authorityControl.VOTE_MANAGER(), address(veFloorStaking));

        // Map some test users
        alice = users[0];

        // Set our user's FLOOR approvals to the staking contract
        vm.prank(alice);
        floor.approve(address(veFloorStaking), 100000 ether);
    }

    function setUp() public {
        // Give our test users 1000 FLOOR tokens each. They already have eth in their
        // account from the environment set up.
        floor.mint(alice, 1000 ether);
    }

    /**
     * VeFloor Staking :: setMaxCapPct
     */

    function test_ShouldNotAllowNonOwnerToSetMaxCapPct() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        veFloorStaking.setMaxCapPct(maxCapPct + 1);
    }

    function test_ShouldNotAllowNonOwnerToSetLowerMaxCapPct() public {
        assertEq(veFloorStaking.maxCapPct(), maxCapPct);

        vm.expectRevert("VeFloorStaking: expected new _maxCapPct to be greater than existing maxCapPct");
        veFloorStaking.setMaxCapPct(maxCapPct - 1);
    }

    function test_ShouldNotAllowNonOwnerToSetMaxCapPctAboveUpperLimit() public {
        vm.expectRevert("VeFloorStaking: expected new _maxCapPct to be non-zero and <= 10000000");
        veFloorStaking.setMaxCapPct(10000001);
    }

    function test_ShouldAllowOwnerToSetMaxCapPct() public {
        assertEq(veFloorStaking.maxCapPct(), maxCapPct);

        veFloorStaking.setMaxCapPct(maxCapPct + 100);
        assertEq(veFloorStaking.maxCapPct(), maxCapPct + 100);
    }

    /**
     * VeFloor Staking :: setVeFloorPerSharePerSec
     */

    function test_ShouldNotAllowNonOwnerToSetVeFloorPerSharePerSec() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        veFloorStaking.setVeFloorPerSharePerSec(1.5 ether);
    }

    function test_ShouldNotAllowOwnerToSetVeFloorPerSharePerSecGreaterThanUpperLimit() public {
        vm.expectRevert("VeFloorStaking: expected _veFloorPerSharePerSec to be <= 1e36");
        veFloorStaking.setVeFloorPerSharePerSec(1e37);
    }

    function test_ShouldAllowOwnerToSetVeFloorPerSharePerSec() public {
        assertEq(veFloorStaking.veFloorPerSharePerSec(), veFloorPerSharePerSec);

        veFloorStaking.setVeFloorPerSharePerSec(1.5 ether);
        assertEq(veFloorStaking.veFloorPerSharePerSec(), 1.5 ether);
    }

    /**
     * VeFloor Staking :: setSpeedUpThreshold
     */

    function test_ShouldNotAllowNonOwnerToSetSpeedUpThreshold() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        veFloorStaking.setSpeedUpThreshold(10);
    }

    function test_ShouldNotAllowOwnerToSetSpeedUpThresholdToZero() public {
        vm.expectRevert("VeFloorStaking: expected _speedUpThreshold to be > 0 and <= 100");
        veFloorStaking.setSpeedUpThreshold(0);
    }

    function test_ShouldNotAllowOwnerToSetSpeedUpThresholdAboveUpperLimit() public {
        vm.expectRevert("VeFloorStaking: expected _speedUpThreshold to be > 0 and <= 100");
        veFloorStaking.setSpeedUpThreshold(101);
    }

    function test_ShouldAllowOwnerToSetSpeedUpThreshold() public {
        assertEq(veFloorStaking.speedUpThreshold(), speedUpThreshold);

        veFloorStaking.setSpeedUpThreshold(10);
        assertEq(veFloorStaking.speedUpThreshold(), 10);
    }

    /**
     * VeFloor Staking :: deposit
     */

    function test_ShouldNotAllowZeroDeposit() public {
        vm.expectRevert("VeFloorStaking: expected deposit amount to be greater than zero");
        vm.prank(alice);
        veFloorStaking.deposit(0);
    }

    function test_ShouldHaveCorrectUpdatedUserInfoAfterFirstTimeDeposit() public {
        // Get Alice's information before any deposit has been made
        (uint256 balance, uint256 rewardDebt, uint256 lastClaimTimestamp, uint256 speedUpEndTimestamp) =
            veFloorStaking.userInfos(alice);

        assertEq(balance, 0);
        assertEq(rewardDebt, 0);
        assertEq(lastClaimTimestamp, 0);
        assertEq(speedUpEndTimestamp, 0);

        // Check Floor balance before deposit
        uint256 startAmount = 1000 ether;
        assertEq(floor.balanceOf(alice), startAmount);

        // Deposit 100 tokens as Alice
        uint256 depositAmount = 100 ether;
        vm.prank(alice);
        veFloorStaking.deposit(depositAmount);

        // Check Floor balance after deposit
        assertEq(floor.balanceOf(alice), startAmount - depositAmount);

        // Get our updated information for Alice
        (balance, rewardDebt, lastClaimTimestamp, speedUpEndTimestamp) = veFloorStaking.userInfos(alice);

        assertEq(balance, depositAmount);
        assertEq(rewardDebt, 0);
        assertEq(lastClaimTimestamp, block.timestamp);
        assertEq(speedUpEndTimestamp, block.timestamp + speedUpDuration);
    }

    function test_ShouldHaveCorrectUpdatedUserBalanceAfterDepositWithNonZeroBalance() public {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);
        veFloorStaking.deposit(5 ether);
        vm.stopPrank();

        (uint256 balance,,,) = veFloorStaking.userInfos(alice);
        assertEq(balance, 105 ether);
    }

    function test_ShouldClaimPendingVeFloorUponDepositingWithNonZeroBalance() public {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);

        // Move the timestamp forward
        skip(30);

        // Check veFloor balance before deposit
        assertEq(veFloor.balanceOf(alice), 0);

        veFloorStaking.deposit(1 ether);

        // Check veFloor balance after deposit
        // Should have sum of:
        // baseVeFloor =  100 * 30 = 3000 veFLOOR
        // speedUpVeFloor = 100 * 30 = 3000 veFLOOR
        assertEq(veFloor.balanceOf(alice), 6000 ether);

        vm.stopPrank();
    }

    function test_ShouldReceiveSpeedUpBenefitsAfterDepositingSpeedUpThresholdWithNonZeroBalance() public {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);

        skip(speedUpDuration);

        veFloorStaking.claim();

        (,,, uint256 speedUpEndTimestamp) = veFloorStaking.userInfos(alice);
        assertEq(speedUpEndTimestamp, 0);

        veFloorStaking.deposit(5 ether);

        (,,, speedUpEndTimestamp) = veFloorStaking.userInfos(alice);
        assertEq(speedUpEndTimestamp, block.timestamp + speedUpDuration);

        vm.stopPrank();
    }

    function test_ShouldNotReceiveSpeedUpBenefitsAfterDepositingLessThatSpeedUpThresholdWithNonZeroBalance() public {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);

        skip(speedUpDuration);

        veFloorStaking.deposit(1 ether);

        (,,, uint256 speedUpEndTimestamp) = veFloorStaking.userInfos(alice);
        assertEq(speedUpEndTimestamp, 0);
    }

    function test_ShouldReceiveSpeedUpBenefitsAfterDepositWithZeroBalance() public {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);

        skip(100);

        veFloorStaking.withdraw(100 ether);

        skip(100);

        veFloorStaking.deposit(1 ether);

        (,,, uint256 speedUpEndTimestamp) = veFloorStaking.userInfos(alice);
        assertEq(speedUpEndTimestamp, block.timestamp + speedUpDuration);

        vm.stopPrank();
    }

    function test_ShouldHaveSpeedUpPeriodExtendedAfterDepositingSpeedUpThresholdAndCurrentlyReceivingSpeedUpBenefits()
        public
    {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);

        (,,, uint256 initialDepositSpeedUpEndTimestamp) = veFloorStaking.userInfos(alice);
        assertEq(initialDepositSpeedUpEndTimestamp, block.timestamp + speedUpDuration);

        // Increase by some amount of time less than speedUpDuration
        skip(speedUpDuration / 2);

        // Deposit speedUpThreshold amount so that speed up period gets extended
        veFloorStaking.deposit(5 ether);

        (,,, uint256 secondDepositSpeedUpEndTimestamp) = veFloorStaking.userInfos(alice);

        assertGt(secondDepositSpeedUpEndTimestamp, initialDepositSpeedUpEndTimestamp);
        assertEq(secondDepositSpeedUpEndTimestamp, block.timestamp + speedUpDuration);

        vm.stopPrank();
    }

    function test_ShouldHaveLastClaimTimestampUpdatedAfterDepositingIfHoldingMaxVeFloorCap() public {
        vm.startPrank(alice);
        veFloorStaking.deposit(100 ether);

        // Increase by `maxCapPct` seconds to ensure that user will have max veFLOOR
        // after claiming.
        skip(maxCapPct);

        veFloorStaking.claim();

        (,, uint256 lastClaimTimestamp,) = veFloorStaking.userInfos(alice);
        assertEq(lastClaimTimestamp, block.timestamp);

        skip(maxCapPct);

        uint256 pendingVeFloor = veFloorStaking.getPendingVeFloor(alice);
        assertEq(pendingVeFloor, 0);

        veFloorStaking.deposit(5 ether);

        (,, lastClaimTimestamp,) = veFloorStaking.userInfos(alice);
        assertEq(lastClaimTimestamp, block.timestamp);
    }

    /**
     * VeFloor Staking :: withdraw
     */

    function test_ShouldNotAllowZeroWithdraw() public {
        vm.expectRevert("VeFloorStaking: expected withdraw amount to be greater than zero");
        vm.prank(alice);
        veFloorStaking.withdraw(0);
    }

    function test_ShouldNotAllowWithdrawAmountGreaterThanUserBalance() public {
        vm.expectRevert("VeFloorStaking: cannot withdraw greater amount of FLOOR than currently staked");
        vm.prank(alice);
        veFloorStaking.withdraw(1);
    }

    function test_ShouldHaveCorrectUpdatedUserInfoAndBalancesAfterWithdraw() public {
        vm.prank(alice);
        veFloorStaking.deposit(100 ether);

        uint256 depositBlock = block.timestamp;

        assertEq(floor.balanceOf(alice), 900 ether);

        skip(speedUpDuration / 2);

        vm.prank(alice);
        veFloorStaking.claim();

        uint256 claimBlock = block.timestamp;

        assertGt(veFloor.balanceOf(alice), 0);

        (uint256 balance, uint256 rewardDebt, uint256 lastClaimTimestamp, uint256 speedUpEndTimestamp) =
            veFloorStaking.userInfos(alice);
        assertEq(balance, 100 ether);
        assertEq(rewardDebt, veFloor.balanceOf(alice) / 2); // Divide by 2 since half of it is from the speed up
        assertEq(lastClaimTimestamp, claimBlock);
        assertEq(speedUpEndTimestamp, depositBlock + speedUpDuration);

        vm.prank(alice);
        veFloorStaking.withdraw(5 ether);

        uint256 withdrawBlock = block.timestamp;

        // Check user info fields are updated correctly
        (balance, rewardDebt, lastClaimTimestamp, speedUpEndTimestamp) = veFloorStaking.userInfos(alice);
        assertEq(balance, 95 ether);
        assertEq(rewardDebt, veFloorStaking.accVeFloorPerShare() * 95);
        assertEq(lastClaimTimestamp, withdrawBlock);
        assertEq(speedUpEndTimestamp, 0);

        // Check user token balances are updated correctly
        assertEq(veFloor.balanceOf(alice), 0);
        assertEq(floor.balanceOf(alice), 905 ether);
    }

    /**
     * VeFloor Staking :: claim
     */

    function test_ShouldNotBeAbleToClaimWithZeroBalance() public {
        vm.expectRevert("VeFloorStaking: cannot claim veFLOOR when no FLOOR is staked");
        vm.prank(alice);
        veFloorStaking.claim();
    }

    function test_ShouldUpdateLastRewardTimestampOnClaim() public {
        vm.prank(alice);
        veFloorStaking.deposit(100 ether);

        skip(100);

        vm.prank(alice);
        veFloorStaking.claim();

        uint256 claimBlock = block.timestamp;

        // lastRewardTimestamp
        assertEq(veFloorStaking.lastRewardTimestamp(), claimBlock);
    }

    function test_ShouldReceiveVeFloorOnClaim() public {
        vm.prank(alice);
        veFloorStaking.deposit(100 ether);

        skip(50);

        // Check veFloor balance before claim
        assertEq(veFloor.balanceOf(alice), 0);

        vm.prank(alice);
        veFloorStaking.claim();

        // Check veFloor balance after claim
        // Should be sum of:
        // baseVeFloor = 100 * 50 = 5000
        // speedUpVeFloor = 100 * 50 = 5000
        assertEq(veFloor.balanceOf(alice), 10000 ether);
    }

    function test_ShouldReceiveCorrectVeFloorIfVeFloorPerSharePerSecIsUpdatedMultipleTimes() public {
        vm.prank(alice);
        veFloorStaking.deposit(100 ether);
        skip(10);

        veFloorStaking.setVeFloorPerSharePerSec(2 ether);
        skip(10);

        veFloorStaking.setVeFloorPerSharePerSec(1.5 ether);
        skip(10);

        // Check veFloor balance before claim
        assertEq(veFloor.balanceOf(alice), 0);

        vm.prank(alice);
        veFloorStaking.claim();

        // Check veFloor balance after claim
        // For baseVeFloor, we're expected to have been generating at a rate of 1 for
        // the first 10 seconds, a rate of 2 for the next 10 seconds, and a rate of
        // 1.5 for the last 10 seconds, i.e.:
        // baseVeFloor = 100 * 10 * 1 + 100 * 10 * 2 + 100 * 10 * 1.5 = 4500
        // speedUpVeFloor = 100 * 30 = 3000
        assertEq(veFloor.balanceOf(alice), 7500 ether);
    }

    /**
     * VeFloor Staking :: updateRewardVars
     */

    function test_ShouldHaveCorrectRewardVarsAfterTimePasses() public {
        vm.prank(alice);
        veFloorStaking.deposit(100 ether);

        uint256 depositBlock = block.timestamp;

        skip(30);

        uint256 accVeFloorPerShareBeforeUpdate = veFloorStaking.accVeFloorPerShare();

        veFloorStaking.updateRewardVars();
        assertEq(veFloorStaking.lastRewardTimestamp(), depositBlock + 30);

        // Increase should be `secondsElapsed * veFloorPerSharePerSec * ACC_VEFLOOR_PER_SHARE_PER_SEC_PRECISION`:
        // = 30 * 1 * 1e18
        assertEq(veFloorStaking.accVeFloorPerShare(), accVeFloorPerShareBeforeUpdate + 30 ether);
    }
}
