// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract SweepWarsTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    // Contract references to be deployed
    CollectionRegistry collectionRegistry;
    EpochManager epochManager;
    FLOOR floor;
    SweepWars sweepWars;
    Treasury treasury;
    StrategyFactory strategyFactory;
    VeFloorStaking veFloor;

    // Trigger to be deployed
    StoreEpochCollectionVotesTrigger storeEpochCollectionVotesTrigger;

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
        // Create our {CollectionRegistry}
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Deploy our FLOOR token
        floor = new FLOOR(address(authorityRegistry));

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry)
        );

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(floor),
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );

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
        sweepWars.setEpochManager(address(epochManager));
        veFloor.setEpochManager(address(epochManager));

        // Register our epoch end trigger that stores our treasury sweep
        storeEpochCollectionVotesTrigger = new StoreEpochCollectionVotesTrigger(
            address(sweepWars)
        );

        storeEpochCollectionVotesTrigger.setEpochManager(address(epochManager));
        epochManager.setEpochEndTrigger(address(storeEpochCollectionVotesTrigger), true);

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection1, SUFFICIENT_LIQUIDITY_COLLECTION);
        collectionRegistry.approveCollection(approvedCollection2, SUFFICIENT_LIQUIDITY_COLLECTION);
        collectionRegistry.approveCollection(approvedCollection3, SUFFICIENT_LIQUIDITY_COLLECTION);
        collectionRegistry.approveCollection(floorTokenCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Set up shorthand for our test users
        (alice, bob) = (users[0], users[1]);
    }

    function setUp() public {
        // Grant Alice and Bob plenty of veFLOOR tokens to play with
        floor.mint(alice, 100 ether);
        floor.mint(bob, 100 ether);

        vm.startPrank(alice);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 6);
        vm.stopPrank();

        vm.startPrank(bob);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 6);
        vm.stopPrank();
    }

    function test_CanStoreSweepWarVotes() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether, false);
        sweepWars.vote(approvedCollection2, 10 ether, false);
        sweepWars.vote(approvedCollection3, 6 ether, false);
        sweepWars.vote(floorTokenCollection, 5 ether, false);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether, false);
        sweepWars.vote(approvedCollection3, 4 ether, true);
        sweepWars.vote(floorTokenCollection, 10 ether, true);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 3 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), 2 ether);
        assertEq(sweepWars.votes(floorTokenCollection), -5 ether);

        // Take the snapshot, though we aren't interested in the returned data
        epochManager.endEpoch();

        // Get the stored votes from our trigger contract
        (address[] memory collections, int[] memory votes) = storeEpochCollectionVotesTrigger.epochSnapshot(0);
        assertEq(collections.length, 4);
        assertEq(collections[0], 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        assertEq(collections[1], 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
        assertEq(collections[2], 0x524cAB2ec69124574082676e6F654a18df49A048);
        assertEq(collections[3], 0x0000000000000000000000000000000000000001);

        assertEq(votes.length, 4);
        assertEq(votes[0], 3 ether);
        assertEq(votes[1], 10 ether);
        assertEq(votes[2], 2 ether);
        assertEq(votes[3], -5 ether);

        // Confirm that an unknown epoch won't return any results
        (collections, votes) = storeEpochCollectionVotesTrigger.epochSnapshot(1);
        assertEq(collections.length, 0);
        assertEq(votes.length, 0);
    }

}
