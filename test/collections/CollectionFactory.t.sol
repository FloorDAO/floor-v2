// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract CollectionFactoryTest is Test {

    /**
     * Deploys our CollectionFactory. We don't set up any approved
     * collections at this point, as we want to allow tests to have
     * control over the state.
     *
     * We can, however, define a number of set valid addresses that
     * we can subsequently reference.
     */
    function setUp() public {}

    /**
     * Confirms that an approved collection can be queried to return
     * a `true` response. This will mean that the test has to first
     * call `approveCollection` before we can check.
     */
    function testIsApproved() public {}

    /**
     * When a collection is not approved, we want the response to
     * return `false`.
     */
    function testIsNotApproved() public {}

    /**
     * When there are no approved collections we should still be able
     * to call our `getApprovedCollections`, but it should just return
     * an empty array.
     */
    function testGetApprovedCollectionsWhenEmpty() public {}

    /**
     * When there is only one approved collection, we should just have
     * a single item in an array returned.
     */
    function testGetApprovedCollectionsWithSingleCollection() public {}

    /**
     * When we have multiple approved collections, our response should
     * be an array of items.
     */
    function testGetApprovedCollectionsWithMultipleCollections() public {}

    /**
     * We need to ensure that we can approve a fresh collection.
     *
     * This should emit {CollectionApproved}.
     */
    function testApproveCollection() public {}

    /**
     * We should have validation when approving a collection to ensure
     * that a NULL address cannot be approved.
     *
     * This should not emit {CollectionApproved}.
     */
    function testApproveNullAddressCollection() public {}

    /**
     * If a collection is already approved, if we try and approve it
     * again then the process will complete but the state won't change.
     *
     * This should not emit {CollectionApproved}.
     */
    function testApproveAlreadyApprovedCollection() public {}

    /**
     * There should be no difference between approving a collection
     * when it has been revoked, and approving the first time round.
     *
     * This should emit {CollectionApproved}.
     */
    function testApprovePreviouslyRevokedCollection() public {}

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to approve collections. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {CollectionApproved}.
     */
    function testCannotApproveCollectionWithoutPermissions() public {}

    /**
     * We should ensure that we can revoke a collection that has
     * been approved.
     *
     * This should emit {CollectionRevoked}.
     */
    function testRevokeCollection() public {}

    /**
     * If a collection has not already been approved, then trying
     * to revoke the collection should have no effect. The call
     * won't revert.
     *
     * This should not emit {CollectionRevoked}.
     */
    function testRevokeUnapprovedCollection() public {}

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to revoke collections. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {CollectionRevoked}.
     */
    function testCannotRevokeCollectionWithoutPermissions() public {}

    /**
     * If an approved collection is being used by a vault, then we
     * should be reverted when if try to revoke it.
     */
    function testRevokeCollectionUsedByVault() public {}

}
