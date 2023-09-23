// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {BaseStrategy} from '@floor/strategies/BaseStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {LiquidateNegativeCollectionTrigger} from '@floor/triggers/LiquidateNegativeCollection.sol';
import {
    CannotVoteWithZeroAmount,
    CollectionNotApproved,
    SweepWars,
    InsufficientVotesAvailable,
    SampleSizeCannotBeZero
} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

import {PricingExecutorMock} from '../mocks/PricingExecutor.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract LiquidateNegativeCollectionTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_493_409;

    // Store our max epoch index
    uint internal constant MAX_EPOCH_INDEX = 3;

    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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
    LiquidateNegativeCollectionTrigger liquidateNegativeCollectionTrigger;

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

        // Set up a revenue strategy
        (, address _strategy) = strategyFactory.deployStrategy(
            bytes32('WETH Rewards Strategy'),
            strategyImplementation,
            abi.encode(WETH, 1 ether, address(epochManager)),
            approvedCollection1
        );

        revenueStrategy = DistributedRevenueStakingStrategy(_strategy);

        // Set up our mock pricing executor
        PricingExecutorMock pricingExecutorMock = new PricingExecutorMock();

        // Register our epoch end trigger that stores our liquidation
        liquidateNegativeCollectionTrigger = new LiquidateNegativeCollectionTrigger(
            address(pricingExecutorMock),
            address(sweepWars),
            address(strategyFactory),
            address(revenueStrategy),
            0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD, // Uniswap Universal Router
            WETH
        );

        // Register the epoch manager against our trigger
        liquidateNegativeCollectionTrigger.setEpochManager(address(epochManager));

        // Add our epoch end trigger
        epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionTrigger), true);

        // Give the liquidation trigger sufficient privleges
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(liquidateNegativeCollectionTrigger));

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

    function test_CanLiquidateNegativeCollection() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether);
        sweepWars.vote(approvedCollection2, 10 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, -2 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection3, -10 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 3 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), -4 ether);
        assertEq(sweepWars.votes(floorTokenCollection), -2 ether);

        // Set up our collection strategies
        _deployStrategy(approvedCollection2);
        _deployStrategy(approvedCollection3);
        _deployStrategy(approvedCollection3);

        /**
         * Our closing vote should look like:
         *
         * Collection 1 : 3
         * Collection 2 : 10
         * Collection 3 : -4
         * Floor Token  : -2
         */

        epochManager.endEpoch();

        // Confirm that our most negative voted collection (collection 3) is liquidated
        (address collection, int votes, uint weth) = liquidateNegativeCollectionTrigger.epochSnapshot(0);
        assertEq(collection, approvedCollection3);
        assertEq(votes, -4 ether);
        assertEq(weth, 166_134540194015727009); // 166.13 WETH
    }

    function test_CanHandleZeroVotes() external {
        // Set up our collection strategies
        _deployStrategy(approvedCollection2);
        _deployStrategy(approvedCollection3);
        _deployStrategy(approvedCollection3);

        epochManager.endEpoch();

        // Confirm that our most negative voted collection (collection 3) is liquidated
        (address collection, int votes, uint weth) = liquidateNegativeCollectionTrigger.epochSnapshot(0);
        assertEq(collection, address(0));
        assertEq(votes, 0);
        assertEq(weth, 0);
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

        // Confirm that no collections were liquidated
        (address collection, int votes, uint weth) = liquidateNegativeCollectionTrigger.epochSnapshot(0);
        assertEq(collection, address(0));
        assertEq(votes, int(0));
        assertEq(weth, 0);
    }

    function test_CanSetSlippage(uint slippage) public {
        // Confirm our default slippage is 5%
        assertEq(liquidateNegativeCollectionTrigger.slippage(), 5000);

        // Ensure our slippage is a valid value
        vm.assume(slippage < 100000);

        // Update our slippage to 10%
        liquidateNegativeCollectionTrigger.setSlippage(slippage);

        // Confirm our new slippage is 10%
        assertEq(liquidateNegativeCollectionTrigger.slippage(), slippage);
    }

    function test_CannotSetSlippageIfNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert('Ownable: caller is not the owner');
        liquidateNegativeCollectionTrigger.setSlippage(5000);
    }

    function test_CannotSetSlippageAboveOneHundredPercent(uint badSlippage) public {
        // Try and set our slippage above 100%
        vm.assume(badSlippage >= 100000);
        vm.expectRevert('Slippage too high');
        liquidateNegativeCollectionTrigger.setSlippage(badSlippage);
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
                address(liquidateNegativeCollectionTrigger),
                IERC20(tokens[i]).balanceOf(address(liquidateNegativeCollectionTrigger)) + amounts[i]
            );
        }
    }
}
