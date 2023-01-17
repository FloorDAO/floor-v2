// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import '../src/contracts/collections/CollectionRegistry.sol';
import {veFLOOR} from '../src/contracts/tokens/VeFloor.sol';
import '../src/contracts/tokens/Floor.sol';
import '../src/contracts/strategies/StrategyRegistry.sol';
import '../src/contracts/RewardsLedger.sol';
import '../src/contracts/Treasury.sol';

import './utilities/Environments.sol';


contract RewardsLedgerTest is FloorTest {

    // Contract references
    FLOOR floor;
    veFLOOR veFloor;
    ERC20Mock erc20;
    CollectionRegistry collectionRegistry;
    RewardsLedger rewards;
    StrategyRegistry strategyRegistry;
    Treasury treasury;

    /**
     * ..
     */
    constructor () {
        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new veFLOOR('veFloor', 'veFLOOR', address(authorityRegistry));

        // Set up a fake ERC20 token that we can test with. We use the {Floor} token
        // contract as a base as this already implements IERC20. We have no initial
        // balance.
        erc20 = new ERC20Mock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(collectionRegistry), // address _collectionRegistry,
            address(strategyRegistry), // address _strategyRegistry,
            address(this),
            address(floor),
            address(veFloor)
        );

        // Set up our {RewardsLedger}
        rewards = new RewardsLedger(
            address(authorityRegistry),
            address(floor),
            address(veFloor),
            address(treasury)
        );

        // Set up our {RewardsLedger} to be a {FLOOR_MANAGER} so that it can correctly
        // mint Floor and veFloor on claims.
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(rewards));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(rewards));
    }

    /**
     * Set up our {RewardsLedger} and the other contracts required to instantiate it.
     */
    function setUp() public {
        // ..
    }

    /**
     * Checks our helper function that gets our {Floor} contract address. This address
     * will be sent during the construct and will be immutable.
     */
    function test_CanGetFloorAddress() public {
        assertEq(address(rewards.floor()), address(floor));
    }

    /**
     * Checks our helper function that gets our {Treasury} contract address. This address
     * will be sent during the construct and will be immutable.
     */
    function test_CanGetTreasuryAddress() public {
        assertEq(address(rewards.treasury()), address(treasury));
    }

    /**
     * We need to make sure that we can allocate tokens to a user. This will be able to
     * support any token being passed, as balance management and checks are not done at
     * this point and should be done before calling.
     *
     * The returned value from our call should just be the amount sent, as it will be
     * the only allocation made and the total amount available to our sender.
     *
     * This should emit {RewardsAllocated}.
     */
    function test_CanAllocate(address token, uint amount) public assumeTokenAndAmount(token, amount) {
        vm.prank(address(treasury));
        uint allocatedAmount = rewards.allocate(address(this), token, amount);

        assertEq(allocatedAmount, amount);
        assertEq(rewards.available(address(this), token), amount);
    }

    /**
     * We should be able to send multiple allocations. This will mean that the return
     * value from our call will be incremental based on the amounts allocated.
     *
     * Each time we allocate, it should emit {RewardsAllocated}.
     */
    function test_CanAllocateMultipleTimes(address token, uint amount1, uint amount2) public assumeTokenAndAmount(token, 1) {
        // Avoid overflow errors with fuzzy values
        vm.assume(amount1 > 0 && amount1 < type(uint).max / 2);
        vm.assume(amount2 > 0 && amount2 < type(uint).max / 2);

        vm.startPrank(address(treasury));
        uint allocatedAmount1 = rewards.allocate(address(this), token, amount1);
        uint allocatedAmount2 = rewards.allocate(address(this), token, amount2);
        vm.stopPrank();

        assertEq(allocatedAmount1, amount1);
        assertEq(allocatedAmount2, amount1 + amount2);

        assertEq(rewards.available(address(this), token), amount1 + amount2);
    }

    /**
     * Our {RewardsLedger} should prevent a NULL token address from being passed.
     */
    function test_CannotAllocateNullToken(uint amount) public {
        vm.assume(amount > 0);

        vm.expectRevert('Invalid token');
        rewards.allocate(address(this), address(0), amount);
    }

    /**
     * Our {RewardsLedger} should prevent a zero amount value from being passed.
     */
    function test_CannotAllocateZeroAmount(address token) public assumeTokenAndAmount(token, 1) {
        vm.expectRevert('Invalid amount');
        rewards.allocate(address(this), token, 0);

    }

    /**
     * Only certain roles are allowed to allocate tokens, so we need to ensure that an
     * unexpected sender is reverted.
     */
    function test_CannotAllocateWithoutPermissions(address token, uint amount) public assumeTokenAndAmount(token, amount) {
        vm.startPrank(address(0));

        vm.expectRevert('Only treasury can allocate');
        rewards.allocate(address(this), token, amount);

        vm.stopPrank();
    }

    /**
     * We should be able to get an array of tokens that the user has allocations either
     * pending or claimed. This will allow us to see how much the user has claimed in
     * total of each token, as well as any pending allocation.
     *
     * For setting up this test we should have tokens in four states:
     *  - Unallocated token
     *  - Allocation with nothing claimed
     *  - Allocation partially claimed
     *  - Allocation fully claimed
     */
    function test_CanGetRewardTokensForUser() public {
        vm.startPrank(address(treasury));
        rewards.allocate(address(100), address(200), 1 ether);
        rewards.allocate(address(100), address(300), 2 ether);
        rewards.allocate(address(100), address(400), 3 ether);
        rewards.allocate(address(100), address(500), 4 ether);
        vm.stopPrank();

        assertEq(rewards.available(address(100), address(200)), 1 ether);
        assertEq(rewards.available(address(100), address(300)), 2 ether);
        assertEq(rewards.available(address(100), address(400)), 3 ether);
        assertEq(rewards.available(address(100), address(500)), 4 ether);

        (address[] memory tokens, uint[] memory amounts) = rewards.availableTokens(address(100));

        assertEq(tokens[0], address(200));
        assertEq(tokens[1], address(300));
        assertEq(tokens[2], address(400));
        assertEq(tokens[3], address(500));

        assertEq(amounts[0], 1 ether);
        assertEq(amounts[1], 2 ether);
        assertEq(amounts[2], 3 ether);
        assertEq(amounts[3], 4 ether);
    }

    function test_AvailableAndClaimed(uint amount1, uint amount2) public {
        vm.assume(amount2 > 0);
        vm.assume(amount1 > amount2);

        address recipient = address(this);
        address token = address(erc20);

        // Without any previous allocation we should still get our available
        // and claimed values.
        assertEq(rewards.available(recipient, token), 0);
        assertEq(rewards.claimed(recipient, token), 0);

        // Make our allocation into the recipient {RewardsLedger}
        vm.prank(address(treasury));
        rewards.allocate(recipient, token, amount1);

        // Mint our token amounts to the {Treasury}
        erc20.mint(address(treasury), amount1);

        // Once we have made an allocation we should get the full amount available
        // and see no claimed value.
        assertEq(rewards.available(recipient, token), amount1);
        assertEq(rewards.claimed(recipient, token), 0);

        rewards.claim(token, amount2);

        // After a partial claim on our allocation, we should see a value in both
        // the available amount as well as the claimed amount.
        assertEq(rewards.available(recipient, token), amount1 - amount2);
        assertEq(rewards.claimed(recipient, token), amount2);

        rewards.claim(token, amount1 - amount2);

        // Finally, after fully claiming all of our allocation we should have no
        // available amount, but see our initial amount being fully claimed.
        assertEq(rewards.available(recipient, token), 0);
        assertEq(rewards.claimed(recipient, token), amount1);
    }

    /**
     * When a user has a sufficient allocation of tokens then they should be able to
     * claim it. This should be tested as a non-Floor token as we have a subsequent
     * test for that use-case.
     *
     * This will take assets from the corresponding vault strategy through which the
     * allocation was made.
     *
     * This should emit {RewardsClaimed}.
     */
    function test_CanClaimTokens(uint amount) public {
        vm.assume(amount > 0);

        vm.prank(address(treasury));
        rewards.allocate(address(this), address(erc20), amount);

        // Transfer our allocation to the {Treasury}
        erc20.mint(address(treasury), amount);

        rewards.claim(address(erc20), amount);
    }

    /**
     *
     */
    function test_CannotClaimTokensWithoutTreasuryBalance(uint amount) public {
        vm.assume(amount > 0);

        vm.prank(address(treasury));
        rewards.allocate(address(this), address(erc20), amount);

        vm.expectRevert('ERC20: transfer amount exceeds balance');
        rewards.claim(address(erc20), amount);
    }

    /**
     * When a user has a sufficient allocation of Floor then they should be able to
     * claim it.
     *
     * This will mint from the Treasury and be sent to the sender as the recipient.
     *
     * This should emit {RewardsClaimed}.
     */
    function test_CanClaimFloorTokens() public {
        vm.prank(address(treasury));
        rewards.allocate(address(this), address(floor), 1 ether);

        rewards.claim(address(floor), 1 ether);
    }

    /**
     * When a user has a sufficient allocation of veFloor then they should be able to
     * claim it.
     *
     * This will mint from the Treasury and be sent to the sender as the recipient.
     *
     * This should emit {RewardsClaimed}.
     */
    function test_CanClaimVeFloorTokens() public {
        vm.prank(address(treasury));
        rewards.allocate(address(this), address(veFloor), 1 ether);

        rewards.claim(address(veFloor), 1 ether);
    }

    /**
     * A user should not be able to claim if they have not been allocated any amount
     * of the token. This should revert.
     */
    function test_CannotClaimTokensWithoutNoAllocation(address token, uint amount) public assumeTokenAndAmount(token, amount) {
        vm.expectRevert('Insufficient allocation');
        rewards.claim(token, amount);
    }

    /**
     * A user should not be able to claim more than the amount of the token that they have
     * been allocated. This should revert.
     */
    function test_CannotClaimTokensWithoutSufficientAllocation(address token, uint amount1, uint amount2) public assumeTokenAndAmount(token, amount1) {
        vm.assume(amount2 > amount1);

        vm.prank(address(treasury));
        rewards.allocate(address(this), token, amount1);

        vm.expectRevert('Insufficient allocation');
        rewards.claim(token, amount2);
    }

    /**
     * Ensure that a Guardian or Govorner can pause and unpause the contract.
     *
     * This should emit {RewardsPaused}.
     */
    function testCanPause() public {
        assertEq(rewards.paused(), false);

        rewards.pause(true);
        assertEq(rewards.paused(), true);

        rewards.pause(false);
        assertEq(rewards.paused(), false);
    }

    /**
     * A user should not be able to claim when the contract is paused, even if they have a
     * valid allocation of the token. This should revert.
     */
    function test_CannotClaimTokensWhenPaused(address token, uint amount) public assumeTokenAndAmount(token, amount) {
        rewards.pause(true);

        vm.prank(address(treasury));
        rewards.allocate(address(this), token, amount);

        vm.expectRevert('Claiming currently paused');
        rewards.claim(token, amount);
    }

    /**
     * Users without expected permissions should not be able to pause the contract.
     *
     * This should not emit {RewardsPaused}.
     */
    function test_CannotPauseWithoutPermissions() public {
        vm.prank(address(0));
        vm.expectRevert('Account does not have admin role');
        rewards.pause(true);
    }

    /**
     * Helper modifier to make validation assumptions around the token and amount.
     */
    modifier assumeTokenAndAmount(address token, uint amount) {
        vm.assume(token != address(0));
        vm.assume(token != address(floor) && token != address(veFloor));
        vm.assume(amount > 0);
        _;
    }

}
