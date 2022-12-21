// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../src/contracts/RewardsLedger.sol';
import '../src/contracts/tokens/Floor.sol';
// import '../src/contracts/Treasury.sol';

import './utilities/Environments.sol';


contract RewardsLedgerTest is FloorTest {

    FLOOR floor;
    RewardsLedger rewards;
    // Treasury treasury;

    /**
     * ..
     */
    constructor () {}

    /**
     * Set up our {RewardsLedger} and the other contracts required to instantiate it.
     */
    function setUp() public {
        // Set up our {Treasury}
        // treasury = new Treasury();

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));

        // Set up our {RewardsLedger}
        rewards = new RewardsLedger(
            address(authorityRegistry),
            address(floor),
            address(0)  // Treasury
        );
    }

    /**
     * Checks our helper function that gets our {Floor} contract address. This address
     * will be sent during the construct and will be immutable.
     */
    function test_CanGetFloorAddress() public {
        assertEq(rewards.floor(), address(floor));
    }

    /**
     * Checks our helper function that gets our {Treasury} contract address. This address
     * will be sent during the construct and will be immutable.
     */
    function test_CanGetTreasuryAddress() public {
        assertEq(rewards.treasury(), address(0));
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
    function testCanAllocate() public {}

    /**
     * We should be able to send multiple allocations. This will mean that the return
     * value from our call will be incremental based on the amounts allocated.
     *
     * Each time we allocate, it should emit {RewardsAllocated}.
     */
    function testCanAllocateMultipleTimes() public {}

    /**
     * Only certain roles are allowed to allocate tokens, so we need to ensure that an
     * unexpected sender is reverted.
     */
    function testCannotAllocateWithoutPermissions() public {}

    /**
     * We should be able to get an array of tokens that the user has allocations either
     * pending or claimed. This will allow us to see how much the user has claimed in
     * total of each token, as well as any pending allocation.
     *
     * For setting up this test we should have tokens in three states:
     *  - Unallocated token
     *  - Allocation with nothing claimed
     *  - Allocation partially claimed
     *  - Allocation fully claimed
     */
    function testCanGetRewardTokensForAUser() public {}

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
    function testCanClaimTokens() public {}

    /**
     * When a user has a sufficient allocation of Floor then they should be able to
     * claim it.
     *
     * This will mint from the Treasury and be sent to the sender as the recipient.
     *
     * This should emit {RewardsClaimed}.
     */
    function testCanClaimFloorTokens() public {}

    /**
     * A user should not be able to claim if they have not been allocated any amount
     * of the token. This should revert.
     */
    function testCannotClaimTokensWithoutNoAllocation() public {}

    /**
     * A user should not be able to claim more than the amount of the token that they have
     * been allocated. This should revert.
     */
    function testCannotClaimTokensWithoutSufficientAllocation(uint amount) public {}

    /**
     * A user should not be able to claim when the contract is paused, even if they have a
     * valid allocation of the token. This should revert.
     */
    function testCannotClaimTokensWhenPaused() public {}

    /**
     * Ensure that a Guardian or Govorner can pause the contract.
     *
     * This should emit {RewardsPaused}.
     */
    function testCanPause() public {}

    /**
     * Ensure that a Guardian or Govorner can unpause the contract.
     *
     * This should emit {RewardsPaused}.
     */
    function testCanUnpause() public {}

    /**
     * Users without expected permissions should not be able to pause the contract.
     *
     * This should not emit {RewardsPaused}.
     */
    function testCannotPauseWithoutPermissions() public {}

    /**
     * Users without expected permissions should not be able to unpause the contract.
     *
     * This should not emit {RewardsPaused}.
     */
    function testCannotUnpauseWithoutPermissions() public {}

}
