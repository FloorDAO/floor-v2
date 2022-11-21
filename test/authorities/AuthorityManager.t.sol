// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import '../utilities/Utilities.sol';


contract AuthorityManagerTest is Test {

    // Set up our expected roles that we will want to test with
    bytes32 private constant TREASURY_MANAGER = keccak256('TreasuryManager');
    bytes32 private constant VAULT_MANAGER = keccak256('VaultManager');
    bytes32 private constant STRATEGY_MANAGER = keccak256('StrategyManager');
    bytes32 private constant COLLECTION_MANAGER = keccak256('CollectionManager');
    bytes32 private constant GOVERNOR = keccak256('Governor');
    bytes32 private constant GUARDIAN = keccak256('Guardian');

    bytes32 private constant UNKNOWN = keccak256('Unknown');

    address alice;
    address bob;
    address carol;

    /**
     * Deploys our AuthorityManager which will in turn create our
     * expected roles and permissions in the constructor.
     */
    function setUp() public {
        // Deploy our manager contract. This will set up a range of roles that
        // we will be using in our system.
        AuthorityManager authorityManager = new AuthorityManager();

        // Set up a small pool of test users
        Utilities utilities = new Utilities();
        (alice, bob, carol) = utilities.createUsers(3, 100 ether, ['Alice', 'Bob', 'Carol']);
    }

    /**
     * When the contract is constructed, we create a range of expected
     * roles that we want to check exist. We can confirm they exist by
     * by checking for the role admin against each role.
     */
    function testExpectedRolesCreatedOnConstruct() public {
        // Our expected roles are defined in our test contract
        assertTrue(authorityManager.roleExists(TREASURY_MANAGER));
        assertTrue(authorityManager.roleExists(VAULT_MANAGER));
        assertTrue(authorityManager.roleExists(STRATEGY_MANAGER));
        assertTrue(authorityManager.roleExists(COLLECTION_MANAGER));
        assertTrue(authorityManager.roleExists(GOVERNOR));
        assertTrue(authorityManager.roleExists(GUARDIAN));

        // We also want to make sure that unknown roles don't return as
        // true as well.
        assertFalse(authorityManager.roleExists(UNKNOWN));
    }

    /**
     * Confirm that a role can be added to a user by the admin of the
     * role. This should emit the {RoleGranted} event.
     */
    function testRoleCanBeGranted() public {
        // We emit the event we expect to see.
        vm.expectEmit(true, true, false, true);
        emit AuthorityManager.RoleGranted(TREASURY_MANAGER, alice, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

        // We want to grant the TreasuryManager role to Alice
        authorityManager.grantRole(TREASURY_MANAGER, alice);
    }

    /**
     * A role should not be able to be granted by a user that is not
     * the role admin.
     */
    function testCannotGrantRoleWithoutPermissions() public {
        // Set our requesting user to be Alice, who does not have permissions
        vm.prank(alice);

        // We should expect our request to be reverted
        vm.expectRevert(bytes('error_message'));
        authorityManager.grantRole(VAULT_MANAGER, bob);
    }

    /**
     * A role should not be able to be granted to a user that already
     * has the role assigned to their address.
     */
    function testCannotBeGrantedExistingRole() public {
        // We initially give Alice the `TreasuryManager` role
        authorityManager.grantRole(TREASURY_MANAGER, alice);

        // We now want to try giving Alice the same role again, which
        // should be reverted.
        vm.expectRevert(bytes('error_message'));
        authorityManager.grantRole(TREASURY_MANAGER, alice);
    }

    /**
     * The `hasRole` function needs to be tested to correctly return
     * both a `true` response when the user has been assigned the role.
     *
     * Inversely, we need to make sure that if the user has not been granted
     * the role, or had the role revoked, then we get a `false` response from
     * our `hasRole` function call.
     */
    function testUserHasRole() public {
        // Confirm that Bob does not have a role to begin with
        assertFalse(authorityManager.hasRole(TREASURY_MANAGER, bob));

        // Once we have granted the role, we can see that Bob now has
        // the role assigned.
        authorityManager.grantRole(TREASURY_MANAGER, alice);
        assertTrue(authorityManager.hasRole(TREASURY_MANAGER, bob));

        // Once we have revoked the role, we can see that Bob now no
        // longer has the role assigned.
        authorityManager.revokeRole(TREASURY_MANAGER, alice);
        assertFalse(authorityManager.hasRole(TREASURY_MANAGER, bob));
    }

    /**
     * We need to ensure that a single address can have multiple roles within
     * the platform.
     */
    function testUserCanHaveMultipleRoles() public {
        authorityManager.grantRole(TREASURY_MANAGER, carol);
        authorityManager.grantRole(VAULT_MANAGER, carol);
        authorityManager.grantRole(STRATEGY_MANAGER, carol);

        assertTrue(authorityManager.hasRole(TREASURY_MANAGER, carol));
        assertTrue(authorityManager.hasRole(VAULT_MANAGER, carol));
        assertTrue(authorityManager.hasRole(STRATEGY_MANAGER, carol));

        assertFalse(authorityManager.hasRole(COLLECTION_MANAGER, carol));
        assertFalse(authorityManager.hasRole(GOVERNOR, carol));
        assertFalse(authorityManager.hasRole(GUARDIAN, carol));
        assertFalse(authorityManager.hasRole(UNKNOWN, carol));
    }

    /**
     * When a user is set up with the Governor or Guardian role, they will
     * have access to all other roles checked. For this test we grant Bob
     * with the Governor role, then with the Guardian role, and confirm that
     * we receive a correct assertion when checking `hasRole` for all other
     * known roles.
     *
     * Unknown roles will still return `False`.
     */
    function testGovernorAndGuardianHaveAllRoles() public {
        authorityManager.grantRole(GOVERNOR, bob);

        assertTrue(authorityManager.hasRole(TREASURY_MANAGER, bob));
        assertTrue(authorityManager.hasRole(VAULT_MANAGER, bob));
        assertTrue(authorityManager.hasRole(STRATEGY_MANAGER, bob));
        assertTrue(authorityManager.hasRole(COLLECTION_MANAGER, bob));
        assertTrue(authorityManager.hasRole(GOVERNOR, bob));
        assertTrue(authorityManager.hasRole(GUARDIAN, bob));
        assertFalse(authorityManager.hasRole(UNKNOWN, bob));

        authorityManager.revokeRole(GOVERNOR, bob);
        authorityManager.grantRole(GUARDIAN, bob);

        assertTrue(authorityManager.hasRole(TREASURY_MANAGER, bob));
        assertTrue(authorityManager.hasRole(VAULT_MANAGER, bob));
        assertTrue(authorityManager.hasRole(STRATEGY_MANAGER, bob));
        assertTrue(authorityManager.hasRole(COLLECTION_MANAGER, bob));
        assertTrue(authorityManager.hasRole(GOVERNOR, bob));
        assertTrue(authorityManager.hasRole(GUARDIAN, bob));
        assertFalse(authorityManager.hasRole(UNKNOWN, bob));
    }

    /**
     * This will test to ensure that we can update the admin role
     * and that permissions are correctly granted and revoked.
     *
     * We have the option of using alternative functionality in which
     * different addresses can be an admins for different roles, but
     * we will want to keep a single admin role to manage all other
     * roles. This role will be assigned to the DAO and guardian.
     *
     * This should emit the {RoleAdminChanged} event.
     */
    function testRoleAdminCanBeUpdated() public {}

    /**
     * We need to ensure that the admin role cannot be updated by
     * a user that does not have permissions to do so.
     */
    function testRoleAdminCannotBeUpdatedWithoutPermissions() public {}

    /**
     * Confirms that a user's role can be revoked if the caller
     * has an admin role.
     *
     * This should emit {RoleRevoked}.
     */
    function testCanRevokeUserRole() public {
        authorityManager.grantRole(STRATEGY_MANAGER, bob);
        assertTrue(authorityManager.hasRole(STRATEGY_MANAGER, bob));

        // We emit the event we expect to see.
        vm.expectEmit(true, true, false, true);
        emit AuthorityManager.RoleRevoked(STRATEGY_MANAGER, bob, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

        authorityManager.revokeRole(STRATEGY_MANAGER, bob);
        assertFalse(authorityManager.hasRole(STRATEGY_MANAGER, bob));
    }

    /**
     * If we try to revoke a user's role when they do not already
     * has the role assigned, then this call will still pass, but
     * not alter any logic.
     *
     * This should not emit {RoleRevoked}.
     */
    function testCannotRevokeUserRoleWithoutExistingRole() public {
        assertFalse(authorityManager.hasRole(STRATEGY_MANAGER, bob));
        authorityManager.revokeRole(STRATEGY_MANAGER, bob);
        assertFalse(authorityManager.hasRole(STRATEGY_MANAGER, bob));
    }

    /**
     * If a non-admin attempts to revoke a user's role, then this
     * call should be reverted.
     */
    function testCannotRevokeUserRoleWithoutPermissions() public {
        authorityManager.grantRole(STRATEGY_MANAGER, bob);
        assertTrue(authorityManager.hasRole(STRATEGY_MANAGER, bob));

        vm.prank(alice);

        vm.expectRevert(bytes('error_message'));
        authorityManager.revokeRole(STRATEGY_MANAGER, bob);
    }

    /**
     * Ensures that a user can renounce their own roles.
     *
     * This should emit {RoleRevoked}.
     */
    function testCanRenounceRole() public {
        // We grant Bob the role that he will be soon renouncing
        authorityManager.grantRole(STRATEGY_MANAGER, bob);
        assertTrue(authorityManager.hasRole(STRATEGY_MANAGER, bob));

        // Set up our requests to be sent from Bob, as renounce uses the
        // `msg.sender` as the target address.
        vm.prank(bob);

        // We emit the event we expect to see.
        vm.expectEmit(true, true, false, true);
        emit AuthorityManager.RoleRevoked(STRATEGY_MANAGER, bob, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

        // We call to renounce Bob's `StrategyManager` role
        authorityManager.renounceRole(STRATEGY_MANAGER);
        assertFalse(authorityManager.hasRole(STRATEGY_MANAGER, bob));
    }

    /**
     * Ensures that a user cannot renounce a role that they have
     * not been granted to them. This should not revert, but should
     * just make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function testCannotRenounceUngrantedRole() public {
        vm.prank(bob);

        assertFalse(authorityManager.hasRole(STRATEGY_MANAGER, bob));
        authorityManager.renounceRole(STRATEGY_MANAGER);
        assertFalse(authorityManager.hasRole(STRATEGY_MANAGER, bob));
    }

    /**
     * Ensures that a user cannot renounce a role that does not exist. This
     * should not revert, but should just make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function testCannotRenounceUnknownRole() public {
        vm.prank(bob);
        authorityManager.renounceRole(UNKNOWN);
    }

}
