// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../src/contracts/collections/CollectionRegistry.sol';
import '../../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import '../../src/contracts/strategies/StrategyRegistry.sol';
import '../../src/contracts/tokens/Floor.sol';
import '../../src/contracts/vaults/Vault.sol';
import '../../src/contracts/vaults/VaultFactory.sol';

import '../mocks/GaugeWeightVote.sol';
import '../utilities/Environments.sol';

contract VaultFactoryTest is FloorTest {
    CollectionRegistry collectionRegistry;
    StrategyRegistry strategyRegistry;
    VaultFactory vaultFactory;
    Vault vaultImplementation;

    address approvedCollection;
    address approvedStrategy;

    address collection;
    address strategy;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_075_930;

    constructor() forkBlock(BLOCK_NUMBER) {}

    /**
     * Deploy the {VaultFactory} contract but don't create any vaults, as we want to
     * allow our tests to have control.
     *
     * We do, however, want to create an approved strategy and collection that we
     * can reference in numerous tests.
     */
    function setUp() public {
        // Create our {StrategyRegistry}
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Define our strategy implementations
        approvedStrategy = address(new NFTXInventoryStakingStrategy(bytes32('Approved Strategy')));
        strategy = address(new NFTXInventoryStakingStrategy(bytes32('Unapproved Strategy')));

        // Approve our test strategy implementation
        strategyRegistry.approveStrategy(approvedStrategy);

        // Create our {CollectionRegistry}
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Set an arbritrary GWV contract to prevent errors
        collectionRegistry.setGaugeWeightVoteContract(address(new GaugeWeightVoteMock(address(collectionRegistry), address(2))));

        // Define our collections (DAI and USDC)
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        collection = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Deploy our vault implementation
        vaultImplementation = new Vault();

        // Deploy our FLOOR token
        FLOOR floor = new FLOOR(address(authorityRegistry));

        // Create our {VaultFactory}
        vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            address(vaultImplementation),
            address(floor)
        );
    }

    /**
     * We should be able to query for all vaults, even when there are none actually
     * created. This won't revert but will just return an empty array.
     */
    function test_VaultsWithNoneCreated() public {
        assertEq(vaultFactory.vaults().length, 0);
    }

    /**
     * When there is only a single vault created, we should still receive an array
     * response but with just a single item inside it.
     */
    function test_VaultsWithSingleVault() public {
        vaultFactory.createVault('Test Vault', approvedStrategy, _strategyInitBytes(), approvedCollection);

        assertEq(vaultFactory.vaults().length, 1);
    }

    /**
     * When we have multiple vaults created we should be able to query them and
     * receive all in an array.
     */
    function test_VaultsWithMultipleVaults() public {
        vaultFactory.createVault('Test Vault 1', approvedStrategy, _strategyInitBytes(), approvedCollection);
        vaultFactory.createVault('Test Vault 2', approvedStrategy, _strategyInitBytes(), approvedCollection);
        vaultFactory.createVault('Test Vault 3', approvedStrategy, _strategyInitBytes(), approvedCollection);

        assertEq(vaultFactory.vaults().length, 3);
    }

    /**
     * We should be able to query for our vault based on it's uint index. This
     * will return the address of the created vault.
     */
    function test_CanGetVault() public {
        // Create a vault and store the address of the new clone
        (uint vaultId, address vault) = vaultFactory.createVault('Test Vault 1', approvedStrategy, _strategyInitBytes(), approvedCollection);

        // Confirm that the vault address stored in our vault factory matches the
        // one that was just cloned.
        assertEq(vaultFactory.vault(vaultId), vault);
    }

    /**
     * If we try and get a vault with an unknown index, we expect a NULL address
     * to be returned.
     */
    function test_CannotGetUnknownVault() public {
        assertEq(vaultFactory.vault(420), address(0));
    }

    /**
     * We should be able to create a vault with valid function parameters.
     *
     * This should emit {VaultCreated}.
     */
    function test_CanCreateVault() public {
        // Create a vault and store the address of the new clone
        (uint vaultId, address vault) = vaultFactory.createVault('Test Vault 1', approvedStrategy, _strategyInitBytes(), approvedCollection);

        assertEq(vaultId, 0);
        require(vault != address(0), 'Invalid vault address');
    }

    /**
     * We should not be able to create a vault with an empty name. This should
     * cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function test_CannotCreateVaultWithEmptyName() public {
        vm.expectRevert(VaultNameCannotBeEmpty.selector);
        vaultFactory.createVault('', approvedStrategy, _strategyInitBytes(), approvedCollection);
    }

    /**
     * We should not be able to create a vault if we have referenced a strategy
     * that has not been approved. This should cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function test_CannotCreateVaultWithUnapprovedStrategy() public {
        vm.expectRevert(abi.encodeWithSelector(StrategyNotApproved.selector, strategy));
        vaultFactory.createVault('Test Vault', strategy, _strategyInitBytes(), approvedCollection);
    }

    /**
     * We should not be able to create a vault if we have referenced a collection
     * that has not been approved. This should cause a revert.
     *
     * This should not emit {VaultCreated}.
     */
    function test_CannotCreateVaultWithUnapprovedCollection() public {
        vm.expectRevert(abi.encodeWithSelector(CollectionNotApproved.selector, collection));
        vaultFactory.createVault('Test Vault', approvedStrategy, _strategyInitBytes(), collection);
    }
}
