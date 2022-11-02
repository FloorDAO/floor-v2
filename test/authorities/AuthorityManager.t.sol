// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract AuthorityManagerTest is Test {

    /**
     * Deploys our AuthorityManager which will in turn create our
     * expected roles and permissions in the constructor.
     */
    function setUp() public {}

    /**
     * When the contract is constructed, we create a range of expected
     * roles that we want to check exist. We can confirm they exist by
     * by checking for the role admin against each role.
     */
    function testExpectedRolesCreatedOnConstruct() public {}

    /**
     * Confirm that a role can be added to a user by the admin of the
     * role. This should emit the {RoleGranted} event.
     */
    function testRoleCanBeGranted() public {}

    /**
     * A role should not be able to be granted by a user that is not
     * the role admin.
     */
    function testCannotGrantRoleWithoutPermissions() public {}

    /**
     * A role should not be able to be granted to a user that already
     * has the role assigned to their address.
     */
    function testCannotBeGrantedExistingRole() public {}

    /**
     * The `hasRole` function needs to be tested to correctly return
     * both a `true` response when the user has been assigned the role.
     */
    function testUserHasRole() public {}

    /**
     * Inversely of the previous test, we need to make sure that if
     * the user has not been granted the role, then we get a `false`
     * response from our `hasRole` function call.
     */
    function testUserNotHasRole() public {}

    /**
     * The `hasRole` function can also be accessed by utilising a
     * modifier, so we need to ensure that this also returns both
     * `true` and `false` responses as expected.
     */
    function testUserHasRoleModifier() public {}

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
    function testCanRevokeUserRole() public {}

    /**
     * If we try to revoke a user's role when they do not already
     * has the role assigned, then this call will still pass, but
     * not alter any logic.
     *
     * This should not emit {RoleRevoked}.
     */
    function testCannotRevokeUserRoleWithoutExistingRole() public {}

    /**
     * If a non-admin attempts to revoke a user's role, then this
     * call should be reverted.
     */
    function testCannotRevokeUserRoleWithoutPermissions() public {}

    /**
     * Ensures that a user can renounce their own roles.
     *
     * This should emit {RoleRevoked}.
     */
    function testCanRenounceRole() public {}

    /**
     * Ensures that a user cannot renounce a role that they have
     * not been granted to them. This should not revert, but should
     * just make no changes.
     *
     * This should not emit {RoleRevoked}.
     */
    function testCannotRenounceUnknownRole() public {}

}
