// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../src/contracts/strategies/StrategyRegistry.sol';

import '../utilities/Environments.sol';

contract StrategyRegistryTest is FloorTest {
    /// Emitted when a strategy is successfully approved
    event StrategyApproved(address contractAddr);

    /// Emitted when a strategy has been successfully revoked
    event StrategyRevoked(address contractAddr);

    // Our authority manager will be global as most tests will use it
    StrategyRegistry strategyRegistry;

    // Set up a small strategy of users to test with
    address alice;

    // Set up a range of addresses to test with
    address internal USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /**
     * Deploys our StrategyFactory. We don't set up any approved
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
     * Confirms that an approved strategy can be queried to return
     * a `true` response. This will mean that the test has to first
     * call `approveStrategy` before we can check.
     */
    function test_IsApproved() public {
        strategyRegistry.approveStrategy(USDC);
        assertTrue(strategyRegistry.isApproved(USDC));
    }

    /**
     * When a strategy is not approved, we want the response to
     * return `false`.
     */
    function test_IsNotApproved() public {
        assertFalse(strategyRegistry.isApproved(USDT));
    }

    /**
     * We need to ensure that we can approve a fresh strategy.
     *
     * This should emit {StrategyApproved}.
     */
    function test_ApproveStrategy() public {
        // Confirm that we start in an unapproved state
        assertFalse(strategyRegistry.isApproved(USDT));

        // Confirm that we are firing our strategy event when our
        // strategy is approved.
        vm.expectEmit(true, true, false, true, address(strategyRegistry));
        emit StrategyApproved(USDT);

        // Approve the DAI strategy
        strategyRegistry.approveStrategy(USDT);

        // Now that the strategy is approved
        assertTrue(strategyRegistry.isApproved(USDT));
    }

    /**
     * We should have validation when approving a strategy to ensure
     * that a NULL address cannot be approved.
     *
     * This should not emit {StrategyApproved}.
     */
    function test_ApproveNullAddressStrategy() public {
        vm.expectRevert('Cannot approve NULL strategy');
        strategyRegistry.approveStrategy(address(0));
    }

    /**
     * If a strategy is already approved, if we try and approve it
     * again then the process will complete but the state won't change.
     *
     * This should not emit {StrategyApproved}.
     */
    function test_ApproveAlreadyApprovedStrategy() public {
        strategyRegistry.approveStrategy(USDC);
        strategyRegistry.approveStrategy(USDC);
    }

    /**
     * There should be no difference between approving a strategy
     * when it has been revoked, and approving the first time round.
     *
     * This should emit {StrategyApproved}.
     */
    function test_ApprovePreviouslyRevokedStrategy() public {
        strategyRegistry.approveStrategy(USDC);
        strategyRegistry.revokeStrategy(USDC);

        // Confirm that we are firing our strategy event when our strategy
        // is approved again.
        vm.expectEmit(true, true, false, true, address(strategyRegistry));
        emit StrategyApproved(USDC);

        strategyRegistry.approveStrategy(USDC);
    }

    /**
     * Only addresses that have been granted the `StrategyManager`
     * role should be able to approve strategies. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {StrategyApproved}.
     */
    function test_CannotApproveStrategyWithoutPermissions() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, msg.sender, ''));
        strategyRegistry.approveStrategy(USDC);
    }

    /**
     * We should ensure that we can revoke a strategy that has
     * been approved.
     *
     * This should emit {StrategyRevoked}.
     */
    function test_RevokeStrategy() public {
        strategyRegistry.approveStrategy(USDC);

        // Confirm that we are firing our strategy event when our strategy
        // is revoked.
        vm.expectEmit(true, true, false, true, address(strategyRegistry));
        emit StrategyRevoked(USDC);

        strategyRegistry.revokeStrategy(USDC);
    }

    /**
     * If a strategy has not already been approved, then trying
     * to revoke the strategy should have no effect. The call
     * will revert to be explicit.
     *
     * This should not emit {StrategyRevoked}.
     */
    function test_RevokeUnapprovedStrategy() public {
        vm.expectRevert('Strategy is not approved');
        strategyRegistry.revokeStrategy(USDT);
    }

    /**
     * Only addresses that have been granted the `StrategyManager`
     * role should be able to revoke strategies. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {StrategyRevoked}.
     */
    function test_CannotRevokeStrategyWithoutPermissions() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, msg.sender, ''));
        strategyRegistry.revokeStrategy(USDC);
    }
}
