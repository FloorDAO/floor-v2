// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract StrategyFactoryTest is Test {

    /**
     * Deploys our StrategyFactory. We don't set up any approved
     * strategies at this point, as we want to allow tests to have
     * control over the state.
     *
     * We can, however, define a number of set valid addresses that
     * we can subsequently reference.
     */
    function setUp() public {}

    /**
     * Confirms that an approved strategy can be queried to return
     * a `true` response. This will mean that the test has to first
     * call `approveStrategy` before we can check.
     */
    function testIsApproved() public {}

    /**
     * When a strategy is not approved, we want the response to
     * return `false`.
     */
    function testIsNotApproved() public {}

    /**
     * We need to ensure that we can approve a fresh strategy.
     *
     * This should emit {StrategyApproved}.
     */
    function testApproveStrategy() public {}

    /**
     * We should have validation when approving a strategy to ensure
     * that a NULL address cannot be approved.
     *
     * This should not emit {StrategyApproved}.
     */
    function testApproveNullAddressStrategy() public {}

    /**
     * If a strategy is already approved, if we try and approve it
     * again then the process will complete but the state won't change.
     *
     * This should not emit {StrategyApproved}.
     */
    function testApproveAlreadyApprovedStrategy() public {}

    /**
     * There should be no difference between approving a strategy
     * when it has been revoked, and approving the first time round.
     *
     * This should emit {StrategyApproved}.
     */
    function testApprovePreviouslyRevokedStrategy() public {}

    /**
     * Only addresses that have been granted the `StrategyManager`
     * role should be able to approve strategies. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {StrategyApproved}.
     */
    function testCannotApproveStrategyWithoutPermissions() public {}

    /**
     * We should ensure that we can revoke a strategy that has
     * been approved.
     *
     * This should emit {StrategyRevoked}.
     */
    function testRevokeStrategy() public {}

    /**
     * If a strategy has not already been approved, then trying
     * to revoke the strategy should have no effect. The call
     * won't revert.
     *
     * This should not emit {StrategyRevoked}.
     */
    function testRevokeUnapprovedStrategy() public {}

    /**
     * Only addresses that have been granted the `StrategyManager`
     * role should be able to revoke strategies. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {StrategyRevoked}.
     */
    function testCannotRevokeStrategyWithoutPermissions() public {}

    /**
     * If an approved strategy is being used by a vault, then we
     * should be reverted when if try to revoke it.
     */
    function testRevokeStrategyUsedByVault() public {}

}
