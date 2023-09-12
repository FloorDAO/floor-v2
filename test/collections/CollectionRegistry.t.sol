// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CannotApproveNullCollection, CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';

import {SweepWarsMock} from '../mocks/SweepWars.sol';
import {PricingExecutorMock} from '../mocks/PricingExecutor.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract CollectionRegistryTest is FloorTest {
    /// Emitted when a collection is successfully approved
    event CollectionApproved(address contractAddr);

    /// Emitted when a collection has been successfully revoked
    event CollectionRevoked(address contractAddr);

    // Our authority manager will be global as most tests will use it
    CollectionRegistry collectionRegistry;

    // Set up a small collection of users to test with
    address alice;

    // Set up a range of addresses to test with
    address internal USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
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
        alice = users[0];
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
    }

    /**
     * Confirms that an approved collection can be queried to return
     * a `true` response. This will mean that the test has to first
     * call `approveCollection` before we can check.
     */
    function test_IsApproved() public {
        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);
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
    function test_CanApproveCollection() public {
        // Confirm that we start in an unapproved state
        assertFalse(collectionRegistry.isApproved(DAI));

        // Get the number of approved collections
        address[] memory collections = collectionRegistry.approvedCollections();
        assertEq(collections.length, 0);

        // Confirm that we are firing our collection event when our
        // collection is approved.
        vm.expectEmit(true, true, false, true, address(collectionRegistry));
        emit CollectionApproved(DAI);

        // Approve the DAI collection
        collectionRegistry.approveCollection(DAI, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Now that the collection is approved
        assertTrue(collectionRegistry.isApproved(DAI));

        // State checks for the array push
        collections = collectionRegistry.approvedCollections();
        assertEq(collections.length, 1);
        assertEq(collections[0], DAI);
    }

    /**
     * We should have validation when approving a collection to ensure
     * that a NULL address cannot be approved.
     *
     * This should not emit {CollectionApproved}.
     */
    function test_CannotApproveNullAddressCollection() public {
        vm.expectRevert(CannotApproveNullCollection.selector);
        collectionRegistry.approveCollection(address(0), SUFFICIENT_LIQUIDITY_COLLECTION);
    }

    /**
     * If a collection is already approved, if we try and approve it
     * again then the process should revert.
     *
     * This should not emit {CollectionApproved}.
     */
    function test_ApproveAlreadyApprovedCollection() public {
        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);

        vm.expectRevert('Collection is already approved');
        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);
    }

    /**
     * We need to ensure that we can unapprove a collection that has been approved.
     *
     * This should emit {CollectionRevoked}.
     */
    function test_CanUnapproveAnApprovedCollection() public {
        // Confirm that we start without `USDC` being approved
        assertFalse(collectionRegistry.isApproved(USDC));

        // Approve our `USDC` collection
        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);
        assertTrue(collectionRegistry.isApproved(USDC));

        // Get the number of approved collections
        address[] memory collections = collectionRegistry.approvedCollections();
        assertEq(collections.length, 1);

        // We can now unapprove our `USDC` collection
        collectionRegistry.unapproveCollection(USDC);
        assertFalse(collectionRegistry.isApproved(USDC));

        // State checks for the array changes
        collections = collectionRegistry.approvedCollections();
        assertEq(collections.length, 0);
    }

    function test_CanUnapproveASandwichedCollection(uint8 topBreadSize, uint8 bottomBreadSize) public {
        for (uint160 i; i < topBreadSize; ++i) {
            collectionRegistry.approveCollection(address(i + 1), SUFFICIENT_LIQUIDITY_COLLECTION);
        }

        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);

        for (uint160 i = topBreadSize; i < uint160(topBreadSize) + bottomBreadSize; ++i) {
            collectionRegistry.approveCollection(address(i + 1), SUFFICIENT_LIQUIDITY_COLLECTION);
        }

        // Confirm that we have an expected array length
        assertEq(collectionRegistry.approvedCollections().length, uint(topBreadSize) + bottomBreadSize + 1);

        // Unapprove our USDC collection
        collectionRegistry.unapproveCollection(USDC);

        // Confirm that our stored collections are as expected. We don't maintain the order
        // of the collections, so we don't try and check this is maintained. Instead, we just
        // iterate over the collection addresses that will have been approved and boolean check.
        address[] memory collections = collectionRegistry.approvedCollections();
        for (uint160 i; i < uint(topBreadSize) + bottomBreadSize; ++i) {
            assertTrue(collectionRegistry.isApproved(address(i + 1)));
        }

        // Confirm that by unapproving the collection, we have the expected length
        assertEq(collections.length, uint(topBreadSize) + bottomBreadSize);
    }

    /**
     * If a collection is not approved when it is unapproved, then we expect the call
     * to be reverted.
     *
     * This should not emit {CollectionRevoked}.
     */
    function test_CannotUnapproveAnUnapprovedCollection() public {
        vm.expectRevert('Collection is not approved');
        collectionRegistry.unapproveCollection(USDC);
    }

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to unapprove collections. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {CollectionRevoked}.
     */
    function testFail_CannotUnapproveCollectionWithoutPermissions() public {
        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);

        vm.prank(alice);
        collectionRegistry.unapproveCollection(USDC);

        assertTrue(collectionRegistry.isApproved(USDC));
    }

    /**
     * Only addresses that have been granted the `CollectionManager`
     * role should be able to approve collections. If the user does
     * not have the role, then the call should be reverted.
     *
     * This should not emit {CollectionApproved}.
     */
    function test_CannotApproveCollectionWithoutPermissions() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.COLLECTION_MANAGER()));
        collectionRegistry.approveCollection(USDC, SUFFICIENT_LIQUIDITY_COLLECTION);

        vm.stopPrank();
    }
}
