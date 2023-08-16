// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {FloorTest} from '../utilities/Environments.sol';

contract AuthorityControlTest is FloorTest {
    // Set up an unknown role for use in tests
    bytes32 private constant UNKNOWN = keccak256('Unknown');

    // Set up a small collection of users to test with
    address alice;
    address bob;
    address carol;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * Deploys our AuthorityControl which will in turn create our
     * expected roles and permissions in the constructor.
     */
    constructor() {
        // Set up a small pool of test users
        (alice, bob, carol) = (users[0], users[1], users[2]);
    }

    /**
     * When the contract is constructed, we create a range of expected
     * roles that we want to check exist. We can confirm they exist by
     * by checking for the role admin against each role.
     */
    function test_ExpectedRolesCreatedOnConstruct() public {
        // Our expected roles are defined in our test contract
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), utilities.deployer()));
        assertTrue(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), utilities.deployer()));
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), utilities.deployer()));
        assertTrue(authorityControl.hasRole(authorityControl.GOVERNOR(), utilities.deployer()));
        assertTrue(authorityControl.hasRole(authorityControl.GUARDIAN(), utilities.deployer()));
    }

    /**
     * Confirm that a role can be added to a user by the admin of the
     * role. This should emit the {RoleGranted} event.
     */
    function test_RoleCanBeGranted() public {
        // We emit the event we expect to see.
        vm.expectEmit(true, true, false, true);
        emit RoleGranted(authorityControl.TREASURY_MANAGER(), alice, DEPLOYER);

        // We want to grant the TreasuryManager role to Alice
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), alice);
    }

    /**
     * A role should not be able to be granted by a user that is not
     * the role admin.
     */
    function test_CannotGrantRoleWithoutPermissions() public {
        // Set our requesting user to be Alice, who does not have permissions
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, bob, authorityControl.GOVERNOR()));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), bob);
        vm.stopPrank();
    }

    /**
     * A role should not be able to be granted to a user that already
     * has the role assigned to their address. This won't fire a revert but
     * will just fail without emitting.
     */
    function test_CannotBeGrantedExistingRole() public {
        assertFalse(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), alice));

        // We initially give Alice the `TreasuryManager` role
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), alice);
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), alice));

        // We now want to try giving Alice the same role again, won't do anything
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), alice);
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), alice));
    }

    /**
     * The `hasRole` function needs to be tested to correctly return
     * both a `true` response when the user has been assigned the role.
     *
     * Inversely, we need to make sure that if the user has not been granted
     * the role, or had the role revoked, then we get a `false` response from
     * our `hasRole` function call.
     */
    function test_UserHasRole() public {
        // Confirm that Bob does not have a role to begin with
        assertFalse(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));

        // Once we have granted the role, we can see that Bob now has
        // the role assigned.
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), bob);
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));

        // Once we have revoked the role, we can see that Bob now no
        // longer has the role assigned.
        authorityRegistry.revokeRole(authorityControl.TREASURY_MANAGER(), bob);
        assertFalse(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));
    }

    /**
     * We need to ensure that a single address can have multiple roles within
     * the platform.
     */
    function test_UserCanHaveMultipleRoles() public {
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), carol);
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), carol);

        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), carol));
        assertTrue(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), carol));

        assertFalse(authorityControl.hasRole(authorityControl.GOVERNOR(), carol));
        assertFalse(authorityControl.hasRole(authorityControl.GUARDIAN(), carol));
        assertFalse(authorityControl.hasRole(UNKNOWN, carol));
    }

    /**
     * When a user is set up with the Governor or Guardian role, they will
     * have access to all other roles checked. For this test we grant Bob
     * with the Governor role, then with the Guardian role, and confirm that
     * we receive a correct assertion when checking `hasRole` for all other
     * known roles.
     */
    function test_GovernorAndGuardianHaveAllRoles() public {
        // When we assign Bob the role of Governor, we remove the deployer
        // account as the Governor as there can only be one.
        authorityRegistry.grantRole(authorityControl.GOVERNOR(), bob);

        // This will give Bob access to all _known_ and _unknown_ roles
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.GOVERNOR(), bob));
        assertTrue(authorityControl.hasRole(UNKNOWN, bob));

        // Since bob is now the Guardian, we need him to grant the role back to the
        // original deployer.
        vm.startPrank(bob);
        authorityRegistry.grantRole(authorityControl.GOVERNOR(), DEPLOYER);
        vm.stopPrank();

        // As the deployer we can now grant Bob the role of Guardian
        authorityRegistry.grantRole(authorityControl.GUARDIAN(), bob);

        // Bob, as Guardian, will have access to all _known_ and _unknown_ roles,
        // apart from the Governor role.
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.GUARDIAN(), bob));
        assertTrue(authorityControl.hasRole(UNKNOWN, bob));
    }

    /**
     * Confirms that a user's role can be revoked if the caller
     * has an admin role.
     *
     * This should emit {RoleRevoked}.
     */
    function test_CanRevokeUserRole() public {
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), bob);
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));

        // We emit the event we expect to see.
        vm.expectEmit(true, true, false, true);
        emit RoleRevoked(authorityControl.COLLECTION_MANAGER(), bob, DEPLOYER);

        authorityRegistry.revokeRole(authorityControl.COLLECTION_MANAGER(), bob);
        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
    }

    /**
     * Checks that when a universal role is revoked, all sub roles are also revoked.
     */
    function test_CanRevokeAllRolesWhenUniversalRoleIsRevoked() public {
        // As the deployer we can now grant Bob the role of Guardian
        authorityRegistry.grantRole(authorityControl.GUARDIAN(), bob);

        // Bob, as Guardian, will have access to all _known_ and _unknown_ roles,
        // apart from the Governor role.
        assertTrue(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
        assertTrue(authorityControl.hasRole(authorityControl.GUARDIAN(), bob));
        assertTrue(authorityControl.hasRole(UNKNOWN, bob));

        // We can't revoke an individual role from Bob, as these are inherited from
        // the Guardian role. So even though we revoke, we still see it is `true`.
        authorityRegistry.revokeRole(authorityControl.STRATEGY_MANAGER(), bob);
        assertTrue(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), bob));

        // When we revoke Bob's Guardian role, we then need to make sure that all
        // of these inherited roles are also revoked.
        authorityRegistry.revokeRole(authorityControl.GUARDIAN(), bob);

        assertFalse(authorityControl.hasRole(authorityControl.TREASURY_MANAGER(), bob));
        assertFalse(authorityControl.hasRole(authorityControl.STRATEGY_MANAGER(), bob));
        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
        assertFalse(authorityControl.hasRole(authorityControl.GUARDIAN(), bob));
        assertFalse(authorityControl.hasRole(UNKNOWN, bob));
    }

    /**
     * If we try to revoke a user's role when they do not already
     * has the role assigned, then this call will still pass, but
     * not alter any logic.
     *
     * This should not emit {RoleRevoked}.
     */
    function test_CannotRevokeUserRoleWithoutExistingRole() public {
        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
        authorityRegistry.revokeRole(authorityControl.COLLECTION_MANAGER(), bob);
        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
    }

    /**
     * If a non-admin attempts to revoke a user's role, then this
     * call should be reverted.
     */
    function testFail_CannotRevokeUserRoleWithoutPermissions() public {
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), bob);
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));

        vm.startPrank(alice);
        authorityRegistry.revokeRole(authorityControl.COLLECTION_MANAGER(), bob);
        vm.stopPrank();
    }

    /**
     * Ensures that a user can renounce their own roles.
     *
     * This should emit {RoleRevoked}.
     */
    function testCanRenounceRole() public {
        // We grant Bob the role that he will be soon renouncing
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), bob);
        assertTrue(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));

        // Set up our requests to be sent from Bob, as renounce uses the
        // `msg.sender` as the target address.
        vm.startPrank(bob);

        // We emit the event we expect to see.
        vm.expectEmit(true, true, false, true);
        emit RoleRevoked(authorityControl.COLLECTION_MANAGER(), bob, DEPLOYER);

        // We call to renounce Bob's `StrategyManager` role
        authorityRegistry.renounceRole(authorityControl.COLLECTION_MANAGER());
        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));

        vm.stopPrank();
    }

    /**
     * Ensures that a user cannot renounce a role that they have
     * not been granted to them. This won't revery, but will just
     * make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function test_CannotRenounceUngrantedRole() public {
        vm.startPrank(bob);

        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));
        authorityRegistry.renounceRole(authorityControl.COLLECTION_MANAGER());
        assertFalse(authorityControl.hasRole(authorityControl.COLLECTION_MANAGER(), bob));

        vm.stopPrank();
    }

    /**
     * Ensures that a user cannot renounce a role that does not exist. This
     * should not revert, but should just make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function test_CannotRenounceUnknownRole() public {
        vm.prank(bob);
        authorityRegistry.renounceRole(UNKNOWN);
    }
}
