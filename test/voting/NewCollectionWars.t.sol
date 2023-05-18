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
import {NewCollectionNftOptionVotingPowerCalculator} from '@floor/voting/calculators/NewCollectionNftOptionVotingPower.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {NewCollectionWarOptions} from '@floor/voting/NewCollectionWarOptions.sol';
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
    NewCollectionWarOptions newCollectionWarOptions;
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

        // Create our {NewCollectionWarOptions} contract
        newCollectionWarOptions = new NewCollectionWarOptions(address(floorNft), address(treasury), address(newCollectionWars));

        // Set our options contract
        newCollectionWars.setOptionsContract(address(newCollectionWarOptions));

        // Create our {EpochManager} contract and assign it to required contracts
        epochManager = new EpochManager();
        newCollectionWars.setEpochManager(address(epochManager));
        newCollectionWarOptions.setEpochManager(address(epochManager));
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

        // Deploy our NFT option calculator
        NewCollectionNftOptionVotingPowerCalculator calculator = new NewCollectionNftOptionVotingPowerCalculator();
        newCollectionWarOptions.setNftVotingPowerCalculator(address(calculator));
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

    function test_CanVoteWithCollectionNft721() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 80;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(newCollectionWars));
        assertEq(mock721.ownerOf(1), address(newCollectionWars));
        assertEq(mock721.ownerOf(2), alice);
    }

    function test_CanVoteWithCollectionNft1155() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 5;
        amounts[1] = 3;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 50;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock1155.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock1155), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(mock1155.balanceOf(address(newCollectionWars), 0), 5);
        assertEq(mock1155.balanceOf(address(newCollectionWars), 1), 3);
        assertEq(mock1155.balanceOf(address(newCollectionWars), 2), 0);

        assertEq(mock1155.balanceOf(alice, 0), 5);
        assertEq(mock1155.balanceOf(alice, 1), 7);
        assertEq(mock1155.balanceOf(alice, 2), 10);
    }

    function test_CannotVoteWithInvalidCollectionNft() external {
        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = 10;

        uint40[] memory amounts = new uint40[](1);
        amounts[0] = 1;

        uint56[] memory exercisePercents = new uint56[](1);
        exercisePercents[0] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);

        vm.expectRevert('ERC721: caller is not token owner or approved');
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(mock721.ownerOf(10), carol);
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

    function test_CanExerciseStakedNft721() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 80;
        exercisePercents[1] = 100;

        uint aliceStartAmount = address(alice).balance;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.endEpoch();

        newCollectionWarOptions.exerciseOptions{value: 1.35 ether}(war, 1.35 ether);

        assertEq(mock721.ownerOf(0), address(treasury));
        assertEq(mock721.ownerOf(1), address(treasury));

        // Alice should still have the same ETH amount that she started with, but will have
        // the additional amounts awaiting her in escrow.
        assertEq(address(alice).balance, aliceStartAmount);
        assertEq(newCollectionWarOptions.payments(address(alice)), 0.6 ether + 0.75 ether);

        // Confirm that Alice can then withdraw the payment
        newCollectionWarOptions.withdrawPayments(payable(alice));
        assertEq(address(alice).balance, aliceStartAmount + 0.6 ether + 0.75 ether);
        assertEq(newCollectionWarOptions.payments(address(alice)), 0);
    }

    function test_CanExerciseStakedNft721ViaSweeper() external {
        /**
         * Create and stake 10 tokens at varying discounts.
         */
        uint[] memory tokenIds = new uint[](10);
        for (uint i; i < 10; ++i) {
            tokenIds[i] = i;
        }

        uint40[] memory amounts = new uint40[](10);
        for (uint i; i < 10; ++i) {
            amounts[i] = 1;
        }

        uint56[] memory exercisePercents = new uint56[](10);
        exercisePercents[0] = 20;
        exercisePercents[1] = 20;
        exercisePercents[2] = 30;
        exercisePercents[3] = 30;
        exercisePercents[4] = 100;
        exercisePercents[5] = 100;
        exercisePercents[6] = 0;
        exercisePercents[7] = 20;
        exercisePercents[8] = 40;
        exercisePercents[9] = 40;

        // Set approval for our all of our tokens and stake them
        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        // Set our minimum sweep amount in the Treasury to ensure we have a sweep
        // amount allocation saved against the epoch sweep.
        treasury.setMinSweepAmount(2 ether);

        // End our epoch, which should create
        epochManager.endEpoch();

        // Try and sweep the wrong epoch, which will detect we don't have the minimum
        // require FLOOR tokens, as the first error.
        vm.expectRevert('Insufficient FLOOR holding');
        treasury.sweepEpoch(0, address(0), '', 3 ether);

        // Try and sweep the epoch as a non-DAO member
        vm.startPrank(bob);
        vm.expectRevert('Only DAO may currently execute');
        treasury.sweepEpoch(1, address(0), '', 1 ether);
        vm.stopPrank();

        // Try and sweep the epoch without an approved sweeper
        vm.expectRevert('Sweeper contract not approved');
        treasury.sweepEpoch(1, address(0), '', 0 ether);

        // Approve our sweeper contract
        address sweeperMock = address(new SweeperMock());
        treasury.approveSweeper(sweeperMock, true);

        // Set up our Mercenary sweeper contract and assign it to our {Treasury}
        treasury.setMercenarySweeper(address(new MercenarySweeper(address(newCollectionWarOptions))));

        // Try and sweep a contract that is not approved
        vm.expectRevert('Sweeper contract not approved');
        treasury.sweepEpoch(1, address(0), '', 0 ether);

        // Approve the sweeper contract
        treasury.approveSweeper(sweeperMock, true);

        // Try and sweep above the sweep amount and it should fail
        vm.expectRevert('Merc Sweep cannot be higher than msg.value');
        treasury.sweepEpoch(1, sweeperMock, '', 3 ether);

        // Now make a sweep call directly via the Treasury to confirm that
        // our implementation is correctly run. We pass a sweeper mock to
        // prevent any exceptions during later sweeping.
        treasury.sweepEpoch(1, sweeperMock, '', 1 ether);

        // The successful mercenary sweep will have purchased specific tokens
        // and moved them into the {Treasury}. We should now own:
        // [6, 0, 1, 7, 2, 3, 8, 9]
        assertEq(IERC721(mock721).ownerOf(0), address(treasury));
        assertEq(IERC721(mock721).ownerOf(1), address(treasury));
        assertEq(IERC721(mock721).ownerOf(2), address(treasury));
        assertEq(IERC721(mock721).ownerOf(3), address(treasury));
        assertEq(IERC721(mock721).ownerOf(4), address(newCollectionWarOptions));
        assertEq(IERC721(mock721).ownerOf(5), address(newCollectionWarOptions));
        assertEq(IERC721(mock721).ownerOf(6), address(treasury));
        assertEq(IERC721(mock721).ownerOf(7), address(treasury));
        assertEq(IERC721(mock721).ownerOf(8), address(newCollectionWarOptions));
        assertEq(IERC721(mock721).ownerOf(9), address(newCollectionWarOptions));
    }

    function test_CannotExerciseStakedNft721WithInsufficientMsgValue() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 80;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.endEpoch();

        vm.expectRevert(); // Throws "EvmError: OutOfFund"
        newCollectionWarOptions.exerciseOptions{value: 0.1 ether}(war, 1 ether);
    }

    function test_CanExerciseStakedNft1155() external {
        uint[] memory tokenIds = new uint[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 1;

        uint40[] memory amounts = new uint40[](3);
        amounts[0] = 5;
        amounts[1] = 3;
        amounts[2] = 2;

        uint56[] memory exercisePercents = new uint56[](3);
        exercisePercents[0] = 25;
        exercisePercents[1] = 35;
        exercisePercents[2] = 45;

        uint aliceStartAmount = address(alice).balance;

        vm.startPrank(alice);
        mock1155.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock1155), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.endEpoch();

        /**
         * From our voting, we should have the following available to the {Treasury}:
         *  - Token #0 - 5x - 0.25
         *  - Token #1 - 3x - 0.35
         *  - Token #1 - 2x - 0.45
         *
         * This gives a total exercise cost of 3.2e, so if we specify a smaller amount of
         * 2e then we should get 5x token #0, 2x token #1 and 0.05e in dust.
         */

        newCollectionWarOptions.exerciseOptions{value: 2 ether}(war, 2 ether);

        assertEq(mock1155.balanceOf(address(newCollectionWars), 0), 0);
        assertEq(mock1155.balanceOf(address(newCollectionWars), 1), 3);

        assertEq(mock1155.balanceOf(address(treasury), 0), 5);
        assertEq(mock1155.balanceOf(address(treasury), 1), 2);

        // Alice should still have the same ETH amount that she started with, but will have
        // the additional amounts awaiting her in escrow.
        assertEq(address(alice).balance, aliceStartAmount);
        assertEq(newCollectionWarOptions.payments(address(alice)), 1.95 ether);

        // Confirm that Alice can then withdraw the payment
        newCollectionWarOptions.withdrawPayments(payable(alice));
        assertEq(address(alice).balance, aliceStartAmount + 1.95 ether);
        assertEq(newCollectionWarOptions.payments(address(alice)), 0);
    }

    function test_CannotReclaimStakedNftInSameEpoch() external {
        uint[] memory singleTokenId = new uint[](1);
        singleTokenId[0] = 0;

        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 100;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(newCollectionWars.collectionVotes(keccak256(abi.encode(war, address(mock721)))), 1.5 ether);

        // Set our exercise percent
        uint56[] memory claimPercents = new uint56[](1);
        claimPercents[0] = 100;

        // Set our indexes against the exercise percents
        uint[] memory index = new uint[](2);
        index[0] = 0;
        index[1] = 1;
        indexes.push(index);

        vm.expectRevert('Currently timelocked');
        vm.prank(alice);
        newCollectionWarOptions.reclaimOptions(war, address(mock721), claimPercents, indexes);

        assertEq(mock721.ownerOf(0), address(newCollectionWars));
        assertEq(mock721.ownerOf(1), address(newCollectionWars));
    }

    function test_CanReclaimStakedNft() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 100;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.endEpoch();
        epochManager.setCurrentEpoch(4);

        // Set our exercise percent
        uint56[] memory claimPercents = new uint56[](1);
        claimPercents[0] = 100;

        // Set our indexes against the exercise percents
        uint[] memory index = new uint[](2);
        index[0] = 0;
        index[1] = 1;
        indexes.push(index);

        vm.startPrank(alice);
        newCollectionWarOptions.reclaimOptions(war, address(mock721), claimPercents, indexes);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), alice);
        assertEq(mock721.ownerOf(1), alice);
    }

    function test_CanReclaimStakedNftThatDidNotWinWithinTimelock() external {
        vm.prank(bob);
        newCollectionWars.vote(address(1));

        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 80;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.endEpoch();

        // Set our exercise percent
        uint56[] memory claimPercents = new uint56[](2);
        claimPercents[0] = 80;
        claimPercents[1] = 100;

        // Set our indexes against the exercise percents
        uint[] memory index = new uint[](1);
        index[0] = 0;
        indexes.push(index);
        indexes.push(index);

        vm.startPrank(alice);
        newCollectionWarOptions.reclaimOptions(war, address(mock721), claimPercents, indexes);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(alice));
        assertEq(mock721.ownerOf(1), address(alice));
    }

    function test_CannotReclaimStakedNftThatIsTimelocked() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 75;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        // Should only be reclaimable from epoch 2
        epochManager.endEpoch();

        // Set our exercise percent
        uint56[] memory claimPercents = new uint56[](2);
        claimPercents[0] = 75;
        claimPercents[1] = 100;

        // Set our indexes against the exercise percents
        uint[] memory index = new uint[](1);
        index[0] = 0;
        indexes.push(index);
        indexes.push(index);

        vm.startPrank(alice);
        vm.expectRevert('Currently timelocked');
        newCollectionWarOptions.reclaimOptions(war, address(mock721), claimPercents, indexes);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(newCollectionWars));
        assertEq(mock721.ownerOf(1), address(newCollectionWars));

        // Now that an additional 2 epoches have ended, it will now be claimable (one for
        // the DAO to exercise and one for Floor NFT holders to exercise).
        vm.warp(block.timestamp + 14 days);
        epochManager.endEpoch();
        epochManager.endEpoch();

        vm.prank(alice);
        newCollectionWarOptions.reclaimOptions(war, address(mock721), claimPercents, indexes);

        assertEq(mock721.ownerOf(0), address(alice));
        assertEq(mock721.ownerOf(1), address(alice));
    }

    function test_CannotHaveAnExercisePercentAbove100(uint56 exercisePercent) external {
        vm.assume(exercisePercent > 100);

        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = 0;

        uint40[] memory amounts = new uint40[](1);
        amounts[0] = 1;

        uint56[] memory exercisePercents = new uint56[](1);
        exercisePercents[0] = exercisePercent;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);

        vm.expectRevert('Exercise percent above 100%');
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();
    }

    function test_CanUpdateCollectionFloorPrice() external {
        // Cast some base votes that should not be manipulated. Bob will cast
        // `50 ether` votes from this transaction.
        vm.prank(bob);
        newCollectionWars.vote(address(mock721));

        // Cast some NFT votes that should be manipulated
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 75;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        bytes32 warCollection = keccak256(abi.encode(war, address(mock721)));

        // Check our collection vote counts with our initial 0.75e token price
        assertEq(newCollectionWars.collectionVotes(warCollection), 50 ether + ((0.75 ether * 125) / 100) + 0.75 ether);
        assertEq(newCollectionWars.collectionNftVotes(warCollection), ((0.75 ether * 125) / 100) + 0.75 ether);

        // 0.75 ether => 1 ether
        newCollectionWars.updateCollectionFloorPrice(address(mock721), 1 ether);

        // Check our collection vote counts
        assertAlmostEqual(newCollectionWars.collectionVotes(warCollection), 50 ether + ((1 ether * 125) / 100) + 1 ether, 1);
        assertAlmostEqual(newCollectionWars.collectionNftVotes(warCollection), ((1 ether * 125) / 100) + 1 ether, 1);

        // 1 ether => 0.5 ether
        newCollectionWars.updateCollectionFloorPrice(address(mock721), 1 ether);

        // Check our collection vote counts
        assertAlmostEqual(newCollectionWars.collectionVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);
        assertAlmostEqual(newCollectionWars.collectionNftVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);

        // 0.5 ether => 0.5 ether
        newCollectionWars.updateCollectionFloorPrice(address(mock721), 0.5 ether);

        // Check our collection vote counts
        assertAlmostEqual(newCollectionWars.collectionVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);
        assertAlmostEqual(newCollectionWars.collectionNftVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);
    }

    function test_CannotUpdateCollectionFloorPriceToZero() external {
        vm.expectRevert('Invalid floor price');
        newCollectionWars.updateCollectionFloorPrice(address(mock721), 0);
    }

    function test_CannotUpdateCollectionFloorPriceToUnknownCollection() external {
        vm.expectRevert('Invalid collection');
        newCollectionWars.updateCollectionFloorPrice(address(6), 1 ether);
    }

    function test_CanExerciseNftAsFloorNftHolder() external {
        // Unpause the floor nft minting
        floorNft.setPaused(false);

        // Create a range of options with varied percents
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint40[] memory amounts = new uint40[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint56[] memory exercisePercents = new uint56[](2);
        exercisePercents[0] = 80;
        exercisePercents[1] = 100;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(newCollectionWarOptions), true);
        newCollectionWarOptions.createOption(war, address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        // Mint an NFT to one of our test users
        vm.prank(alice);
        floorNft.mint{value: 0.05 ether}(1);

        // Attempt to exercise without a winning collection
        vm.expectRevert('FloorWar has not ended');
        vm.prank(alice);
        newCollectionWarOptions.holderExerciseOptions{value: 0.8 ether}(war, 0, exercisePercents[0], 0);

        // End the war and enter the DAO epoch window
        epochManager.endEpoch();

        // Attempt to exercise as a holder before the correct window has opened
        vm.expectRevert('Outside exercise window');
        vm.prank(alice);
        newCollectionWarOptions.holderExerciseOptions{value: 0.8 ether}(war, 0, exercisePercents[0], 0);

        // Move to the holder epoch window
        vm.warp(block.timestamp + 7 days);
        epochManager.endEpoch();

        // Approve our locker
        vm.prank(alice);
        floorNft.approveLocker(address(newCollectionWarOptions), 0);

        // Attempt to exercise an option that does not exist
        vm.expectRevert('Nothing staked at index');
        vm.prank(alice);
        newCollectionWarOptions.holderExerciseOptions{value: 0.8 ether}(war, 0, exercisePercents[0], 1);

        // Exercise as a holder
        vm.prank(alice);
        newCollectionWarOptions.holderExerciseOptions{value: 0.8 ether}(war, 0, exercisePercents[0], 0);

        // Attempt to exercise again as a holder
        vm.expectRevert('Token is already locked');
        vm.prank(alice);
        newCollectionWarOptions.holderExerciseOptions{value: 0.8 ether}(war, 0, exercisePercents[0], 0);

        // Attempt to exercise as a non-holder
        vm.expectRevert('User is not owner, nor currently staked with an approved staker');
        vm.prank(bob);
        newCollectionWarOptions.holderExerciseOptions{value: 1 ether}(war, 0, exercisePercents[1], 0);

        // Move forward another epoch to exit the holder epoch window
        vm.warp(block.timestamp + 7 days);
        epochManager.endEpoch();

        // Attempt to exercise outside the window, in the future
        vm.expectRevert('Outside exercise window');
        vm.prank(alice);
        newCollectionWarOptions.holderExerciseOptions{value: 1 ether}(war, 0, exercisePercents[1], 0);
    }

    function test_CanCalculateNftVotingPower() external {
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 0), 2.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 10), 1.9 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 20), 1.8 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 30), 1.7 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 40), 1.6 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 50), 1.5 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 60), 1.4 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 70), 1.3 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 80), 1.2 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 90), 1.1 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 100), 1.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 110), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 120), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 130), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 140), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 150), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 160), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 170), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 180), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 190), 0.0 ether);
        assertEq(newCollectionWarOptions.nftVotingPower(war, address(0), 1 ether, 200), 0.0 ether);
    }

    /**
     * Allows our contract to receive dust ETH back from sweeps.
     */
    receive() external payable {}
}
