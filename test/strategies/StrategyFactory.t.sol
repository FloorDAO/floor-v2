// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {CollectionNotApproved, StrategyFactory, StrategyNameCannotBeEmpty} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {StrategyNotApproved} from '@floor/utils/Errors.sol';
import {Treasury} from '@floor/Treasury.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

import {RevertingStrategy} from '../mocks/RevertingStrategy.sol';
import {SweepWarsMock} from '../mocks/SweepWars.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract StrategyFactoryTest is FloorTest {
    /// Store our deployed contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;

    /// Store our approved collections and strategies that we can reference in tests
    address approvedCollection;
    address approvedStrategy;

    /// Store our non-approved collections that we can reference in tests
    address unapprovedCollection;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_075_930;

    /// Store a test user
    address alice;

    constructor() forkBlock(BLOCK_NUMBER) {
        super._deployAuthority();
    }

    /**
     * Deploy the {StrategyFactory} contract but don't create any strategies, as we want to
     * allow our tests to have control.
     *
     * We do, however, want to create an approved strategy and collection that we
     * can reference in numerous tests.
     */
    function setUp() public {
        // Define our strategy implementations
        approvedStrategy = address(new NFTXInventoryStakingStrategy());

        // Create our {CollectionRegistry}
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Define our collections (DAI and USDC)
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        unapprovedCollection = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection);

        // Set up our strategy registry
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        strategyRegistry.approveStrategy(approvedStrategy, true);

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry)
        );

        // Deploy our {Treasury} and assign it to our {StrategyFactory}
        Treasury treasury = new Treasury(
            address(authorityRegistry),
            address(1),
            WETH
        );
        strategyFactory.setTreasury(address(treasury));

        // Set our test user
        alice = users[1];
    }

    /**
     * We should be able to query for all strategies, even when there are none actually
     * created. This won't revert but will just return an empty array.
     */
    function test_StrategysWithNoneCreated() public {
        assertEq(strategyFactory.strategies().length, 0);
    }

    /**
     * When there is only a single strategy created, we should still receive an array
     * response but with just a single item inside it.
     */
    function test_StrategysWithSingleStrategy() public {
        strategyFactory.deployStrategy('Test Strategy', approvedStrategy, _strategyInitBytes(), approvedCollection);

        assertEq(strategyFactory.strategies().length, 1);
    }

    /**
     * When we have multiple strategies created we should be able to query them and
     * receive all in an array.
     */
    function test_StrategysWithMultipleStrategys() public {
        strategyFactory.deployStrategy('Test Strategy 1', approvedStrategy, _strategyInitBytes(), approvedCollection);
        strategyFactory.deployStrategy('Test Strategy 2', approvedStrategy, _strategyInitBytes(), approvedCollection);
        strategyFactory.deployStrategy('Test Strategy 3', approvedStrategy, _strategyInitBytes(), approvedCollection);

        assertEq(strategyFactory.strategies().length, 3);
    }

    /**
     * We should be able to query for our strategy based on it's uint index. This
     * will return the address of the created strategy.
     */
    function test_CanGetStrategy() public {
        // Create a strategy and store the address of the new clone
        (uint strategyId, address _strategy) =
            strategyFactory.deployStrategy('Test Strategy 1', approvedStrategy, _strategyInitBytes(), approvedCollection);

        // Confirm that the strategy address stored in our strategy factory matches the
        // one that was just cloned.
        assertEq(strategyFactory.strategy(strategyId), _strategy);
    }

    /**
     * If we try and get a strategy with an unknown index, we expect a NULL address
     * to be returned.
     */
    function test_CannotGetUnknownStrategy() public {
        assertEq(strategyFactory.strategy(420), address(0));
    }

    /**
     * We should be able to create a strategy with valid function parameters.
     *
     * This should emit {StrategyCreated}.
     */
    function test_CanCreateStrategy() public {
        // Create a strategy and store the address of the new clone
        (uint strategyId, address _strategy) =
            strategyFactory.deployStrategy('Test Strategy 1', approvedStrategy, _strategyInitBytes(), approvedCollection);

        assertEq(strategyId, 0);
        require(_strategy != address(0), 'Invalid strategy address');

        // Confirm our base information
        IBaseStrategy strategy = IBaseStrategy(_strategy);
        assertEq(strategy.name(), 'Test Strategy 1');
        assertEq(strategy.strategyId(), 0);

        // Confirm that the address is as expected
        assertEq(
            _strategy,
            Clones.predictDeterministicAddress(approvedStrategy, 0, address(strategyFactory))
        );
    }

    function test_CannotCreateStrategyWithUnapprovedStrategyImplementation(address _strategy) external {
        // Ensure we don't use our approved strategy
        vm.assume(_strategy != approvedStrategy);

        // Create a strategy and store the address of the new clone
        vm.expectRevert(abi.encodeWithSelector(StrategyNotApproved.selector, _strategy));
        strategyFactory.deployStrategy('Test Strategy 1', _strategy, _strategyInitBytes(), approvedCollection);
    }

    function test_CanDeploySameStrategyMultipleTimes() public {
        // Create two strategies
        (uint strategyIdA, address strategyA) = strategyFactory.deployStrategy('Test Strategy 1', approvedStrategy, _strategyInitBytes(), approvedCollection);
        (uint strategyIdB, address strategyB) = strategyFactory.deployStrategy('Test Strategy 1', approvedStrategy, _strategyInitBytes(), approvedCollection);

        // Confirm their sequential IDs
        assertEq(strategyIdA, 0);
        assertEq(strategyIdB, 1);

        // Confirm that the addresses are different
        assertFalse(strategyA == strategyB);

        // Confirm the code matches
        assertEq(strategyA.code, strategyB.code);
    }

    /**
     * We should not be able to create a strategy with an empty name. This should
     * cause a revert.
     *
     * This should not emit {StrategyCreated}.
     */
    function test_CannotCreateStrategyWithEmptyName() public {
        vm.expectRevert(StrategyNameCannotBeEmpty.selector);
        strategyFactory.deployStrategy('', approvedStrategy, _strategyInitBytes(), approvedCollection);
    }

    /**
     * We should not be able to create a strategy if we have referenced a collection
     * that has not been approved. This should cause a revert.
     *
     * This should not emit {StrategyCreated}.
     */
    function test_CannotCreateStrategyWithUnapprovedCollection() public {
        vm.expectRevert(abi.encodeWithSelector(CollectionNotApproved.selector, unapprovedCollection));
        strategyFactory.deployStrategy('Test Strategy', approvedStrategy, _strategyInitBytes(), unapprovedCollection);
    }

    function test_CannotDeployStrategyWithoutPermissions() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.STRATEGY_MANAGER()));
        strategyFactory.deployStrategy('Test Strategy 1', approvedStrategy, _strategyInitBytes(), approvedCollection);

        vm.stopPrank();
    }

    function test_CanBypassRevertingStrategy() public {
        // Deploy our reverting strategy
        RevertingStrategy strategy = new RevertingStrategy();

        // Approve our strategy to be used and deployed
        strategyRegistry.approveStrategy(address(strategy), true);

        // We can deploy the strategy
        (uint strategyId, address strategyAddr) = strategyFactory.deployStrategy('Reverting Strategy', address(strategy), _strategyInitBytes(), approvedCollection);

        // We can confirm that the calls we expect will now revert
        vm.expectRevert('Prevent Available');
        strategyFactory.snapshot(0);
        vm.expectRevert('Prevent Harvest');
        strategyFactory.harvest(strategyId);
        vm.expectRevert('Unable to withdraw');
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));
        vm.expectRevert('Prevent Withdraw Percentage');
        strategyFactory.withdrawPercentage(strategyAddr, 20_00);

        // Bypass the strategy in the factory
        strategyFactory.bypassStrategy(strategyAddr, true);

        // Now make the calls again and confirm that they no longer revert
        strategyFactory.snapshot(0);
        strategyFactory.harvest(strategyId);
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));
        strategyFactory.withdrawPercentage(strategyAddr, 20_00);

        // Then un-bypass the strategy to confirm that we can
        strategyFactory.bypassStrategy(strategyAddr, false);

        // .. and we should go back to reverting as before
        vm.expectRevert('Prevent Available');
        strategyFactory.snapshot(0);
    }
}
