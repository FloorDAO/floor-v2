// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {LiquidateAllNegativeCollectionsManualTrigger} from '@floor/triggers/LiquidateAllNegativeCollectionsManual.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract LiquidateAllNegativeCollectionsManualTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_493_409;

    /// Event fired when losing collection strategy is liquidated
    event CollectionTokensLiquidated(address _collection, address[] _strategies, uint _percentage);

    // Contract references to be deployed
    CollectionRegistry collectionRegistry;
    DistributedRevenueStakingStrategy revenueStrategy;
    EpochManager epochManager;
    FLOOR floor;
    SweepWars sweepWars;
    Treasury treasury;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;
    VeFloorStaking veFloor;

    // Trigger to be deployed
    LiquidateAllNegativeCollectionsManualTrigger liquidateNegativeCollectionManualTrigger;

    // A set of collections to be referenced during testing
    address approvedCollection1 = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address approvedCollection2 = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address approvedCollection3 = 0x524cAB2ec69124574082676e6F654a18df49A048;
    address unapprovedCollection1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address unapprovedCollection2 = 0xd68c4149Ec6fC585124E8827a2b102b68712543c;

    // Constant for floor token collection vote
    address floorTokenCollection = address(1);

    // Store some test user wallets
    address alice;
    address bob;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Define our strategy implementation
        address strategyImplementation = address(new DistributedRevenueStakingStrategy(address(authorityRegistry)));

        // Create our {StrategyRegistry}
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        strategyRegistry.approveStrategy(strategyImplementation, true);

        // Create our {CollectionRegistry}
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection1);
        collectionRegistry.approveCollection(approvedCollection2);
        collectionRegistry.approveCollection(approvedCollection3);
        collectionRegistry.approveCollection(floorTokenCollection);

        // Deploy our FLOOR token
        floor = new FLOOR(address(authorityRegistry));

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry)
        );

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(floor),
            WETH
        );

        // Set the treasury against our strategy factory
        strategyFactory.setTreasury(address(treasury));

        // Set up our veFloor token
        veFloor = new VeFloorStaking(floor, address(treasury));

        // Now that we have all our dependencies, we can deploy our {SweepWars} contract
        sweepWars = new SweepWars(
            address(collectionRegistry),
            address(strategyFactory),
            address(veFloor),
            address(authorityRegistry),
            address(treasury)
        );

        // Create our {EpochManager} and assign the contract to our test contracts
        epochManager = new EpochManager();
        veFloor.setEpochManager(address(epochManager));

        // Assign relevant war contracts
        veFloor.setVotingContracts(address(0), address(sweepWars));

        // Register our epoch end trigger that stores our liquidation
        liquidateNegativeCollectionManualTrigger = new LiquidateAllNegativeCollectionsManualTrigger(
            address(sweepWars),
            address(strategyFactory)
        );

        // Register the epoch manager against our trigger
        liquidateNegativeCollectionManualTrigger.setEpochManager(address(epochManager));

        // Add our epoch end trigger
        epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionManualTrigger), true);

        // Give the liquidation trigger sufficient privleges
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(liquidateNegativeCollectionManualTrigger));

        // Set up shorthand for our test users
        (alice, bob) = (users[0], users[1]);
    }

    function setUp() public {
        // Grant Alice and Bob plenty of veFLOOR tokens to play with
        floor.mint(alice, 100 ether);
        floor.mint(bob, 100 ether);

        vm.startPrank(alice);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, MAX_EPOCH_INDEX);
        vm.stopPrank();

        vm.startPrank(bob);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, MAX_EPOCH_INDEX);
        vm.stopPrank();
    }

    function test_CanLiquidateSingleNegativeCollectionWithStrategies() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether);
        sweepWars.vote(approvedCollection2, 10 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, -2 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection3, -8 ether);
        sweepWars.vote(floorTokenCollection, 2 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 3 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), -2 ether);
        assertEq(sweepWars.votes(floorTokenCollection), 0 ether);

        // Set up our collection strategies
        _deployStrategy(approvedCollection2);
        _deployStrategy(approvedCollection3);
        _deployStrategy(approvedCollection3);

        /**
         * Our closing vote should look like:
         *
         * Collection 1 :  3
         * Collection 2 : 10
         * Collection 3 : -2
         * Floor Token  :  0
         */

        address[] memory strategies = new address[](2);
        strategies[0] = 0x669538dFce92584272a4d413a408948E990e9BFe;
        strategies[1] = 0x31DF500B2550B78B29507E5E7705F89FA1EeCb17;

        vm.expectEmit(true, true, false, true, address(liquidateNegativeCollectionManualTrigger));
        emit CollectionTokensLiquidated(approvedCollection3, strategies, 13_33);

        epochManager.endEpoch();
    }

    function test_CanLiquidateSingleNegativeCollectionWithNoStrategies() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether);
        sweepWars.vote(approvedCollection2, 10 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, -2 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(floorTokenCollection, -6 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 3 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), 6 ether);
        assertEq(sweepWars.votes(floorTokenCollection), -8 ether);

        // Set up our collection strategies
        _deployStrategy(approvedCollection2);
        _deployStrategy(approvedCollection3);
        _deployStrategy(approvedCollection3);

        /**
         * Our closing vote should look like:
         *
         * Collection 1 :  3
         * Collection 2 : 10
         * Collection 3 :  6
         * Floor Token  : -8
         */

        vm.expectEmit(true, true, false, true, address(liquidateNegativeCollectionManualTrigger));
        emit CollectionTokensLiquidated(floorTokenCollection, new address[](0), 29_62);

        epochManager.endEpoch();
    }

    function test_CanLiquidateMultipleNegativeCollections() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, -3 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, 3 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection2, -1 ether);
        sweepWars.vote(approvedCollection3, -10 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), -2 ether);
        assertEq(sweepWars.votes(approvedCollection2), -1 ether);
        assertEq(sweepWars.votes(approvedCollection3), -4 ether);
        assertEq(sweepWars.votes(floorTokenCollection), 3 ether);

        // Set up our collection strategies
        _deployStrategy(approvedCollection2);
        _deployStrategy(approvedCollection3);
        _deployStrategy(approvedCollection3);

        /**
         * Our closing vote should look like:
         *
         * Collection 1 : -2
         * Collection 2 : -1
         * Collection 3 : -4
         * Floor Token  :  3
         */

        address[] memory collection1Strategies = new address[](0);
        address[] memory collection2Strategies = new address[](1);
        collection2Strategies[0] = 0x16b0A8E55AD92746B04B7a10399a873B82141846;
        address[] memory collection3Strategies = new address[](2);
        collection3Strategies[0] = 0x669538dFce92584272a4d413a408948E990e9BFe;
        collection3Strategies[1] = 0x31DF500B2550B78B29507E5E7705F89FA1EeCb17;

        vm.expectEmit(true, true, false, true, address(liquidateNegativeCollectionManualTrigger));
        emit CollectionTokensLiquidated(approvedCollection1, collection1Strategies, 20_00);
        emit CollectionTokensLiquidated(approvedCollection2, collection2Strategies, 10_00);
        emit CollectionTokensLiquidated(approvedCollection3, collection3Strategies, 40_00);

        epochManager.endEpoch();
    }

    function test_CanHandleZeroVotes() external {
        // Set up our collection strategies
        _deployStrategy(approvedCollection2);
        _deployStrategy(approvedCollection3);
        _deployStrategy(approvedCollection3);

        epochManager.endEpoch();
    }

    function test_CanDetectNoNegativeVotes() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether);
        sweepWars.vote(approvedCollection2, 10 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, 5 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection3, -4 ether);
        sweepWars.vote(floorTokenCollection, -1 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 3 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), 2 ether);
        assertEq(sweepWars.votes(floorTokenCollection), 4 ether);

        /**
         * Our closing vote should look like:
         *
         * Collection 1 : 3
         * Collection 2 : 10
         * Collection 3 : 2
         * Floor Token  : 4
         */

        epochManager.endEpoch();
    }

    function _deployStrategy(address collection) internal {
        address[] memory tokens = new address[](2);
        tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens[1] = 0x269616D549D7e8Eaa82DFb17028d0B212D11232A;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 50 ether;
        amounts[1] = 1 ether;

        address strategyImplementation = address(new RevenueStakingStrategy());
        strategyRegistry.approveStrategy(strategyImplementation, true);

        // Set up a strategy
        (, address _strategy) = strategyFactory.deployStrategy(
            bytes32('Collection Strategy'),
            strategyImplementation,
            abi.encode(tokens),
            collection
        );

        // Set up a mock for the percentage output
        vm.mockCall(
            address(strategyFactory),
            abi.encodeWithSelector(StrategyFactory.withdrawPercentage.selector, _strategy, 2105),
            abi.encode(tokens, amounts)
        );

        // Give our trigger sufficient tokens
        for (uint i; i < tokens.length; ++i) {
            deal(
                tokens[i],
                address(liquidateNegativeCollectionManualTrigger),
                IERC20(tokens[i]).balanceOf(address(liquidateNegativeCollectionManualTrigger)) + amounts[i]
            );
        }
    }
}
