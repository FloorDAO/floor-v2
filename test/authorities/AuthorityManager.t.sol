// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import '../../src/contracts/authorities/AuthorityManager.sol';
import '../utilities/Utilities.sol';


contract AuthorityManagerTest is Test {

    // Set up an unknown role for use in tests
    bytes32 private constant UNKNOWN = keccak256('Unknown');

    // Our authority manager will be global as most tests will use it
    AuthorityManager authorityManager;
    Utilities utilities;

    // Set up a small collection of users to test with
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
        authorityManager = new AuthorityManager();

        // Set up our utilities class
        utilities = new Utilities();

        // Set up a small pool of test users
        address payable[] memory users = utilities.createUsers(3, 100 ether);
        (alice, bob, carol) = (users[0], users[1], users[2]);
    }

    /**
     * When the contract is constructed, we create a range of expected
     * roles that we want to check exist. We can confirm they exist by
     * by checking for the role admin against each role.
     */
    function test_ExpectedRolesCreatedOnConstruct() public {
        // Our expected roles are defined in our test contract
        assertTrue(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), utilities.deployer()));
        assertTrue(authorityManager.hasRole(authorityManager.VAULT_MANAGER(), utilities.deployer()));
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), utilities.deployer()));
        assertTrue(authorityManager.hasRole(authorityManager.COLLECTION_MANAGER(), utilities.deployer()));
        assertTrue(authorityManager.hasRole(authorityManager.GOVERNOR(), utilities.deployer()));
        assertTrue(authorityManager.hasRole(authorityManager.GUARDIAN(), utilities.deployer()));
    }

    /**
     * Confirm that a role can be added to a user by the admin of the
     * role. This should emit the {RoleGranted} event.
     */
    function test_RoleCanBeGranted() public {
        // We emit the event we expect to see.
        // vm.expectEmit(true, true, false, true);
        // emit AuthorityManager.RoleGranted(TREASURY_MANAGER, alice, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

        // We want to grant the TreasuryManager role to Alice
        authorityManager.grantRole(authorityManager.TREASURY_MANAGER(), alice);
    }

    /**
     * A role should not be able to be granted by a user that is not
     * the role admin.
     */
    function testFail_CannotGrantRoleWithoutPermissions() public {
        // Set our requesting user to be Alice, who does not have permissions
        vm.startPrank(alice);

        authorityManager.grantRole(authorityManager.VAULT_MANAGER(), bob);

        vm.stopPrank();
    }

    /**
     * A role should not be able to be granted to a user that already
     * has the role assigned to their address. This won't fire a revert but
     * will just fail without emitting.
     */
    function test_CannotBeGrantedExistingRole() public {
        // We initially give Alice the `TreasuryManager` role
        authorityManager.grantRole(authorityManager.TREASURY_MANAGER(), alice);

        // We now want to try giving Alice the same role again, won't do anything
        authorityManager.grantRole(authorityManager.TREASURY_MANAGER(), alice);
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
        assertFalse(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), bob));

        // Once we have granted the role, we can see that Bob now has
        // the role assigned.
        authorityManager.grantRole(authorityManager.TREASURY_MANAGER(), bob);
        assertTrue(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), bob));

        // Once we have revoked the role, we can see that Bob now no
        // longer has the role assigned.
        authorityManager.revokeRole(authorityManager.TREASURY_MANAGER(), bob);
        assertFalse(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), bob));
    }

    /**
     * We need to ensure that a single address can have multiple roles within
     * the platform.
     */
    function test_UserCanHaveMultipleRoles() public {
        authorityManager.grantRole(authorityManager.TREASURY_MANAGER(), carol);
        authorityManager.grantRole(authorityManager.VAULT_MANAGER(), carol);
        authorityManager.grantRole(authorityManager.STRATEGY_MANAGER(), carol);

        assertTrue(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), carol));
        assertTrue(authorityManager.hasRole(authorityManager.VAULT_MANAGER(), carol));
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), carol));

        assertFalse(authorityManager.hasRole(authorityManager.COLLECTION_MANAGER(), carol));
        assertFalse(authorityManager.hasRole(authorityManager.GOVERNOR(), carol));
        assertFalse(authorityManager.hasRole(authorityManager.GUARDIAN(), carol));
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
    function _test_GovernorAndGuardianHaveAllRoles() public {
        authorityManager.grantRole(authorityManager.GOVERNOR(), bob);

        assertTrue(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.VAULT_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.COLLECTION_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.GOVERNOR(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.GUARDIAN(), bob));
        assertFalse(authorityManager.hasRole(UNKNOWN, bob));

        authorityManager.revokeRole(authorityManager.GOVERNOR(), bob);
        authorityManager.grantRole(authorityManager.GUARDIAN(), bob);

        assertTrue(authorityManager.hasRole(authorityManager.TREASURY_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.VAULT_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.COLLECTION_MANAGER(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.GOVERNOR(), bob));
        assertTrue(authorityManager.hasRole(authorityManager.GUARDIAN(), bob));
        assertFalse(authorityManager.hasRole(UNKNOWN, bob));
    }

    /**
     * Confirms that a user's role can be revoked if the caller
     * has an admin role.
     *
     * This should emit {RoleRevoked}.
     */
    function test_CanRevokeUserRole() public {
        authorityManager.grantRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        // We emit the event we expect to see.
        // vm.expectEmit(true, true, false, true);
        // emit AuthorityManager.RoleRevoked(STRATEGY_MANAGER, bob, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

        authorityManager.revokeRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertFalse(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));
    }

    /**
     * If we try to revoke a user's role when they do not already
     * has the role assigned, then this call will still pass, but
     * not alter any logic.
     *
     * This should not emit {RoleRevoked}.
     */
    function test_CannotRevokeUserRoleWithoutExistingRole() public {
        assertFalse(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));
        authorityManager.revokeRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertFalse(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));
    }

    /**
     * If a non-admin attempts to revoke a user's role, then this
     * call should be reverted.
     */
    function testFail_CannotRevokeUserRoleWithoutPermissions() public {
        authorityManager.grantRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        vm.startPrank(alice);
        authorityManager.revokeRole(authorityManager.STRATEGY_MANAGER(), bob);
        vm.stopPrank();
    }

    /**
     * Ensures that a user can renounce their own roles.
     *
     * This should emit {RoleRevoked}.
     */
    function _testCanRenounceRole() public {
        // We grant Bob the role that he will be soon renouncing
        authorityManager.grantRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        // Set up our requests to be sent from Bob, as renounce uses the
        // `msg.sender` as the target address.
        vm.startPrank(bob);

        // We emit the event we expect to see.
        // vm.expectEmit(true, true, false, true);
        // emit AuthorityManager.RoleRevoked(STRATEGY_MANAGER, bob, 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84);

        // We call to renounce Bob's `StrategyManager` role
        authorityManager.renounceRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertFalse(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        vm.stopPrank();
    }

    /**
     * Ensures that a user cannot renounce a role that they have
     * not been granted to them. This should revert, and should
     * make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function testFail_CannotRenounceUngrantedRole() public {
        vm.startPrank(bob);

        assertFalse(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        vm.expectRevert('AccessControl: can only renounce roles for self');
        authorityManager.renounceRole(authorityManager.STRATEGY_MANAGER(), bob);

        assertFalse(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        vm.stopPrank();
    }

    /**
     * Ensures that a user cannot renounce another user's role. This
     * should revert.
     *
     * This should not emit {RoleRevoked}.
     */
    function testFail_CannotRenounceAnotherUsersRole() public {
        // We grant Bob the role that he will be soon renouncing
        authorityManager.grantRole(authorityManager.STRATEGY_MANAGER(), bob);
        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));

        vm.expectRevert('AccessControl: can only renounce roles for self');

        vm.prank(alice);
        authorityManager.renounceRole(authorityManager.STRATEGY_MANAGER(), bob);

        assertTrue(authorityManager.hasRole(authorityManager.STRATEGY_MANAGER(), bob));
    }

    /**
     * Ensures that a user cannot renounce a role that does not exist. This
     * should not revert, but should just make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function test_CannotRenounceUnknownRole() public {
        vm.prank(bob);
        authorityManager.renounceRole(UNKNOWN, bob);
    }

}
