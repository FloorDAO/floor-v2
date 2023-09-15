// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {SweepWarsMock} from '../mocks/SweepWars.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract StrategyRegistryTest is FloorTest {
    /// Emitted when a strategy is approved or unapproved
    event ApprovedStrategyUpdated(address contractAddr, bool approved);

    // Our authority manager will be global as most tests will use it
    StrategyRegistry strategyRegistry;

    // Set up a small collection of users to test with
    address alice;

    /**
     * Deploys our StrategyRegistry. We don't set up any approved
     * strategies at this point, as we want to allow tests to have
     * control over the state.
     *
     * We can, however, define a number of set valid addresses that
     * we can subsequently reference.
     */
    function setUp() public {
        alice = users[0];
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
    }

    /**
     * We need to ensure that we can approve a fresh strategy.
     *
     * This should emit {ApprovedStrategyUpdated}.
     */
    function test_CanApproveStrategy(address strategy) public {
        // Prevent a zero-address being tested
        vm.assume(strategy != address(0));

        // Confirm that we start in an unapproved state
        assertFalse(strategyRegistry.isApproved(strategy));

        // Confirm that we are firing our strategy event when our
        // strategy is approved.
        vm.expectEmit(true, true, false, true, address(strategyRegistry));
        emit ApprovedStrategyUpdated(strategy, true);

        // Approve the strategy
        strategyRegistry.approveStrategy(strategy, true);

        // Now that the strategy is approved
        assertTrue(strategyRegistry.isApproved(strategy));
    }

    /**
     * We should have validation when approving a strategy to ensure
     * that a NULL address cannot be approved.
     *
     * This should not emit {ApprovedStrategyUpdated}.
     */
    function test_CannotApproveNullAddressCollection() public {
        vm.expectRevert(CannotSetNullAddress.selector);
        strategyRegistry.approveStrategy(address(0), true);
    }

    /**
     * If a strategy is already approved, if we try and approve it
     * again then the process should revert.
     *
     * This should not emit {ApprovedStrategyUpdated}.
     */
    function test_CannotApproveAlreadyApprovedCollection(address strategy) public {
        // Prevent a zero-address being tested
        vm.assume(strategy != address(0));

        strategyRegistry.approveStrategy(strategy, true);

        vm.expectRevert('Strategy is already new state');
        strategyRegistry.approveStrategy(strategy, true);
    }

    /**
     * We need to ensure that we can unapprove a strategy that has been approved.
     *
     * This should emit {ApprovedStrategyUpdated}.
     */
    function test_CanUnapproveAnApprovedCollection(address strategy) public {
        // Prevent a zero-address being tested
        vm.assume(strategy != address(0));

        // Confirm that we start without `USDC` being approved
        assertFalse(strategyRegistry.isApproved(strategy));

        // Approve our strategy
        strategyRegistry.approveStrategy(strategy, true);
        assertTrue(strategyRegistry.isApproved(strategy));

        // We can now unapprove our strategy
        strategyRegistry.approveStrategy(strategy, false);
        assertFalse(strategyRegistry.isApproved(strategy));
    }

    /**
     * If a strategy is not approved when it is unapproved, then we expect the call
     * to be reverted.
     *
     * This should not emit {ApprovedStrategyUpdated}.
     */
    function test_CannotUnapproveAnUnapprovedCollection(address strategy) public {
        // Prevent a zero-address being tested
        vm.assume(strategy != address(0));

        vm.expectRevert('Strategy is already new state');
        strategyRegistry.approveStrategy(strategy, false);
    }

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to unapprove strategies. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {ApprovedStrategyUpdated}.
     */
    function test_CannotUnapproveStrategyWithoutPermissions(address strategy) public {
        // Prevent a zero-address being tested
        vm.assume(strategy != address(0));

        strategyRegistry.approveStrategy(strategy, true);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.TREASURY_MANAGER()));
        strategyRegistry.approveStrategy(strategy, false);

        vm.stopPrank();
    }

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to approve strategies. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {ApprovedStrategyUpdated}.
     */
    function test_CannotApproveStrategyWithoutPermissions(address strategy) public {
        // Prevent a zero-address being tested
        vm.assume(strategy != address(0));

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.TREASURY_MANAGER()));
        strategyRegistry.approveStrategy(strategy, true);

        vm.stopPrank();
    }
}
