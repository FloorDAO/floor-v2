// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract VaultFactoryTest is Test {

    /**
     * Deploy the {VaultFactory} contract but don't create any vaults, as we want to
     * allow our tests to have control.
     *
     * We do, however, want to create an approved strategy and collection that we
     * can reference in numerous tests.
     */
    function setUp() public {}

    /**
     * We should be able to query for all vaults, even when there are none actually
     * created. This won't revert but will just return an empty array.
     */
    function testVaultsWithNoneCreated() public {}

    /**
     * When there is only a single vault created, we should still receive an array
     * response but with just a single item inside it.
     */
    function testVaultsWithSingleVault() public {}

    /**
     * When we have multiple vaults created we should be able to query them and
     * receive all in an array.
     */
    function testVaultsWithMultipleVaults() public {}

    /**
     * We should be able to query for our vault based on it's uint index. This
     * will return the address of the created vault.
     */
    function testCanGetVault() public {}

    /**
     * If we try and get a vault with an unknown index, we expect a NULL address
     * to be returned.
     */
    function testCannotGetUnknownVault() public {}

    /**
     * We should be able to create a vault with valid function parameters.
     *
     * This should emit {VaultCreated}.
     */
    function testCanCreateVault() public {}

    /**
     * We should not be able to create a vault with an empty name. This should
     * cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function testCannotCreateVaultWithEmptyName() public {}

    /**
     * We should not be able to create a vault with an empty symbol. This should
     * cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function testCannotCreateVaultWithEmptySymbol() public {}

    /**
     * We should not be able to create a vault if we have referenced a strategy
     * that has not been approved. This should cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function testCannotCreateVaultWithUnapprovedStrategy() public {}

    /**
     * We should not be able to create a vault if we have referenced a collection
     * that has not been approved. This should cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function testCannotCreateVaultWithUnapprovedCollection() public {}

    /**
     * If the contract is paused when we try and create a vault with valid information,
     * the process to be reverted.
     *
     * This should not emit {VaultCreated}.
     */
    function testCannotCreateVaultWhenPaused() public {}

    /**
     * Governors and Guardians should be able to pause the contract which will prevent
     * vaults from being created. We only need to confirm that the contract can be
     * paused in this test, as other tests confirm that creation is prevented.
     *
     * This should emit {VaultCreationPaused}.
     */
    function testCanPause() public {}

    /**
     * Governors and Guardians should be able to unpause the contract which will again
     * allow vaults to be created. We only need to confirm that the contract can be
     * unpaused in this test, as other tests confirm that creation is working.
     *
     * This should emit {VaultCreationPaused}.
     */
    function testCanUnpause() public {}

}
