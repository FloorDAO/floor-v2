// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {PricingExecutorMock} from '../mocks/PricingExecutor.sol';

import {MercenarySweeper} from '@floor/sweepers/Mercenary.sol';
import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {FloorNft} from '@floor/tokens/FloorNft.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager, EpochTimelocked, NoPricingExecutorSet} from '@floor/EpochManager.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, Treasury} from '@floor/Treasury.sol';

import {ERC1155Mock} from '../mocks/erc/ERC1155Mock.sol';
import {ERC721Mock} from '../mocks/erc/ERC721Mock.sol';
import {SweeperMock} from '../mocks/Sweeper.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract NewCollectionWarsTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    // Contract references to be deployed
    EpochManager epochManager;
    FLOOR floor;
    FloorNft floorNft;
    NewCollectionWars newCollectionWars;
    VeFloorStaking veFloor;
    CollectionRegistry collectionRegistry;
    Treasury treasury;
    PricingExecutorMock pricingExecutorMock;
    SweepWars sweepWars;
    StrategyFactory strategyFactory;

    address alice;
    address bob;
    address carol;

    uint war;

    ERC721Mock mock721;
    ERC1155Mock mock1155;

    uint[][] indexes;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new VeFloorStaking(floor, address(this));

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

        // Mock some WETH into our {Treasury} to fund the sweeps
        deal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, address(treasury), 1000 ether);

        // Create our Gauge Weight Vote contract
        sweepWars = new SweepWars(
            address(collectionRegistry),
            address(strategyFactory),
            address(veFloor),
            address(authorityRegistry),
            address(treasury)
        );

        // Set up our veFloor token
        veFloor = new VeFloorStaking(floor, address(treasury));

        // Create our Floor NFT
        floorNft = new FloorNft(
            'Floor NFT',  // _name
            'nftFloor',   // _symbol
            250,          // _maxSupply
            5             // _maxMintAmountPerTx
        );

        // Create our {NewCollectionWars} contract
        newCollectionWars = new NewCollectionWars(address(authorityRegistry), address(veFloor));

        // Create our {EpochManager} contract and assign it to required contracts
        epochManager = new EpochManager();
        newCollectionWars.setEpochManager(address(epochManager));
        veFloor.setEpochManager(address(epochManager));
        sweepWars.setEpochManager(address(epochManager));
        treasury.setEpochManager(address(epochManager));

        epochManager.setContracts(
            address(collectionRegistry),
            address(newCollectionWars),
            address(pricingExecutorMock),
            address(treasury),
            address(strategyFactory),
            address(sweepWars),
            address(0) // Vote Market not needed for these tests
        );

        // Create some mock tokens
        mock721 = new ERC721Mock();
        mock1155 = new ERC1155Mock();

        // Map some users to simpler addresses
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Give our test users a selection of ERC721 and ERC1155 tokens
        for (uint i; i < 10; ++i) {
            mock721.mint(alice, i);
            mock1155.mint(alice, i, 10, bytes(''));

            mock721.mint(carol, i + 10);
            mock1155.mint(carol, i + 10, 10, bytes(''));
        }

    }

    function setUp() public {
        // Set up a collections array
        address[] memory collections = new address[](5);
        collections[0] = address(1);
        collections[1] = address(mock721);
        collections[2] = address(mock1155);
        collections[3] = address(4);
        collections[4] = address(5);

        bool[] memory isErc1155 = new bool[](5);
        isErc1155[0] = false;
        isErc1155[1] = false;
        isErc1155[2] = true;
        isErc1155[3] = false;
        isErc1155[4] = false;

        uint[] memory floorPrices = new uint[](5);
        floorPrices[0] = 1 ether;
        floorPrices[1] = 0.75 ether;
        floorPrices[2] = 1 ether;
        floorPrices[3] = 0.5 ether;
        floorPrices[4] = 0.5 ether;

        // Set up a war
        war = newCollectionWars.createFloorWar(1, collections, isErc1155, floorPrices);

        // Move to our next epoch to activate the created war at epoch 1
        epochManager.endEpoch();

        // Skip forward so that epoch is unlocked
        vm.warp(block.timestamp + 7 days);

        // Grant Alice and Bob plenty of veFLOOR tokens to play with
        floor.mint(alice, 100 ether);
        floor.mint(bob, 50 ether);

        vm.startPrank(alice);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 6);
        vm.stopPrank();

        vm.startPrank(bob);
        floor.approve(address(veFloor), 50 ether);
        veFloor.deposit(50 ether, 6);
        vm.stopPrank();
    }

    function test_CanGetUserVotingPower() external {
        assertEq(newCollectionWars.userVotingPower(alice), 100 ether);
        assertEq(newCollectionWars.userVotingPower(bob), 50 ether);
        assertEq(newCollectionWars.userVotingPower(carol), 0 ether);

        vm.prank(alice);
        newCollectionWars.vote(address(1));

        assertEq(newCollectionWars.userVotingPower(alice), 100 ether);
        assertEq(newCollectionWars.userVotingPower(bob), 50 ether);
        assertEq(newCollectionWars.userVotingPower(carol), 0 ether);
    }

    function test_CanGetUserVotesAvailable() external {
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 100 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, carol), 0 ether);

        vm.prank(alice);
        newCollectionWars.vote(address(1));

        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, carol), 0 ether);

        assertEq(newCollectionWars.userVotesAvailable(war + 1, alice), 100 ether);
        assertEq(newCollectionWars.userVotesAvailable(war + 1, bob), 50 ether);
        assertEq(newCollectionWars.userVotesAvailable(war + 1, carol), 0 ether);
    }

    function test_CanVote() external {
        vm.prank(alice);
        newCollectionWars.vote(address(1));

        vm.prank(bob);
        newCollectionWars.vote(address(mock721));

        vm.prank(carol);
        newCollectionWars.vote(address(mock1155));
    }

    function test_CanRevote() external {
        vm.startPrank(alice);
        newCollectionWars.vote(address(mock721));
        newCollectionWars.vote(address(mock1155));
        vm.stopPrank();
    }

    function test_CannotVoteOnInvalidWarCollection() external {
        vm.expectRevert('Invalid collection');
        vm.prank(alice);
        newCollectionWars.vote(address(10));
    }

    function test_CanCreateFloorWar() external {
        // This is tested in the instantiation of the test
    }

    function test_CanEndFloorWar(uint currentEpoch) external {
        vm.assume(currentEpoch > 0);
        vm.assume(currentEpoch <= 10);

        epochManager.setCurrentEpoch(currentEpoch);

        vm.prank(address(epochManager));
        newCollectionWars.endFloorWar();
    }

    function test_CannotEndFloorWarThatDoesNotExist() external {
        // This will end the existing war
        epochManager.endEpoch();

        // We then try to end another floor war, but none should exist
        vm.expectRevert('No war currently running');
        vm.prank(address(epochManager));
        newCollectionWars.endFloorWar();
    }

    function test_CannotUpdateCollectionFloorPriceToZero() external {
        vm.expectRevert('Invalid floor price');
        newCollectionWars.updateCollectionFloorPrice(address(mock721), 0);
    }

    function test_CannotUpdateCollectionFloorPriceToUnknownCollection() external {
        vm.expectRevert('Invalid collection');
        newCollectionWars.updateCollectionFloorPrice(address(6), 1 ether);
    }

    /**
     * Allows our contract to receive dust ETH back from sweeps.
     */
    receive() external payable {}
}
