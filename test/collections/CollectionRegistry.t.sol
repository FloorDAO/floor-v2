// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import '../../src/contracts/authorities/AuthorityManager.sol';
import '../../src/contracts/collections/CollectionRegistry.sol';
import '../utilities/Utilities.sol';


contract CollectionRegistryTest is Test {

    /// Emitted when a collection is successfully approved
    event CollectionApproved(address contractAddr);

    /// Emitted when a collection has been successfully revoked
    event CollectionRevoked(address contractAddr);

    // Our authority manager will be global as most tests will use it
    AuthorityManager authorityManager;
    CollectionRegistry collectionRegistry;
    Utilities utilities;

    // Set up a small collection of users to test with
    address alice;

    // Set up a range of addresses to test with
    address internal USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;

    /**
     * Deploys our CollectionRegistry. We don't set up any approved
     * collections at this point, as we want to allow tests to have
     * control over the state.
     *
     * We can, however, define a number of set valid addresses that
     * we can subsequently reference.
     */
    function setUp() public {
        authorityManager = new AuthorityManager();
        collectionRegistry = new CollectionRegistry();

        // Set up our utilities class
        utilities = new Utilities();

        // Set up a small pool of test users
        address payable[] memory users = utilities.createUsers(1, 100 ether);
        alice = users[0];
    }

    /**
     * Confirms that an approved collection can be queried to return
     * a `true` response. This will mean that the test has to first
     * call `approveCollection` before we can check.
     */
    function test_IsApproved() public {
        collectionRegistry.approveCollection(USDC);
        assertTrue(collectionRegistry.isApproved(USDC));
    }

    /**
     * When a collection is not approved, we want the response to
     * return `false`.
     */
    function test_IsNotApproved() public {
        assertFalse(collectionRegistry.isApproved(SHIB));
    }

    /**
     * We need to ensure that we can approve a fresh collection.
     *
     * This should emit {CollectionApproved}.
     */
    function test_ApproveCollection() public {
        // Confirm that we start in an unapproved state
        assertFalse(collectionRegistry.isApproved(DAI));

        // Confirm that we are firing our collection event when our
        // collection is approved.
        vm.expectEmit(true, true, false, true, address(collectionRegistry));
        emit CollectionApproved(DAI);

        // Approve the DAI collection
        collectionRegistry.approveCollection(DAI);

        // Now that the collection is approved
        assertTrue(collectionRegistry.isApproved(DAI));
    }

    /**
     * We should have validation when approving a collection to ensure
     * that a NULL address cannot be approved.
     *
     * This should not emit {CollectionApproved}.
     */
    function test_ApproveNullAddressCollection() public {
        vm.expectRevert('Cannot approve NULL collection');
        collectionRegistry.approveCollection(address(0));
    }

    /**
     * If a collection is already approved, if we try and approve it
     * again then the process will complete but the state won't change.
     *
     * This should not emit {CollectionApproved}.
     */
    function test_ApproveAlreadyApprovedCollection() public {
        collectionRegistry.approveCollection(USDC);
        collectionRegistry.approveCollection(USDC);
    }

    /**
     * There should be no difference between approving a collection
     * when it has been revoked, and approving the first time round.
     *
     * This should emit {CollectionApproved}.
     */
    function test_ApprovePreviouslyRevokedCollection() public {
        collectionRegistry.approveCollection(USDC);
        collectionRegistry.revokeCollection(USDC);

        // Confirm that we are firing our collection event when our
        // collection is re-approved.
        vm.expectEmit(true, true, false, true, address(collectionRegistry));
        emit CollectionApproved(USDC);

        collectionRegistry.approveCollection(USDC);
    }

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to approve collections. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {CollectionApproved}.
     */
    function testFail_CannotApproveCollectionWithoutPermissions() public {
        vm.prank(alice);
        collectionRegistry.approveCollection(USDC);
    }

    /**
     * We should ensure that we can revoke a collection that has
     * been approved.
     *
     * This should emit {CollectionRevoked}.
     */
    function test_RevokeCollection() public {
        collectionRegistry.approveCollection(USDC);

        vm.expectEmit(true, true, false, true, address(collectionRegistry));
        emit CollectionRevoked(USDC);

        collectionRegistry.revokeCollection(USDC);
    }

    /**
     * If a collection has not already been approved, then trying
     * to revoke the collection should have no effect. The call
     * won't revert.
     *
     * This should not emit {CollectionRevoked}.
     */
    function test_RevokeUnapprovedCollection() public {
        collectionRegistry.revokeCollection(USDC);
    }

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to revoke collections. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {CollectionRevoked}.
     */
    function testFail_CannotRevokeCollectionWithoutPermissions() public {
        vm.prank(alice);
        collectionRegistry.revokeCollection(USDC);
    }

    /**
     * If an approved collection is being used by a vault, then we
     * should be reverted when if try to revoke it.
     */
    function test_RevokeCollectionUsedByVault() public {
        // Coming soon..
    }

}
