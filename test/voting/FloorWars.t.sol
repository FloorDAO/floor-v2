// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {PricingExecutorMock} from '../mocks/PricingExecutor.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {Vault} from '@floor/vaults/Vault.sol';
import {VaultFactory} from '@floor/vaults/VaultFactory.sol';
import {FloorWars} from '@floor/voting/FloorWars.sol';
import {GaugeWeightVote} from '@floor/voting/GaugeWeightVote.sol';
import {EpochManager, EpochTimelocked, NoPricingExecutorSet} from '@floor/EpochManager.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, Treasury} from '@floor/Treasury.sol';

import {ERC1155Mock} from '../mocks/erc/ERC1155Mock.sol';
import {ERC721Mock} from '../mocks/erc/ERC721Mock.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract FloorWarsTest is FloorTest {

    // Contract references to be deployed
    EpochManager epochManager;
    FLOOR floor;
    FloorWars floorWars;
    VeFloorStaking veFloor;
    CollectionRegistry collectionRegistry;
    StrategyRegistry strategyRegistry;
    Treasury treasury;
    PricingExecutorMock pricingExecutorMock;
    GaugeWeightVote gaugeWeightVote;
    VaultFactory vaultFactory;

    address alice;
    address bob;
    address carol;

    uint war;

    ERC721Mock mock721;
    ERC1155Mock mock1155;

    constructor() {
        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Deploy our vault implementations
        address vaultImplementation = address(new Vault());

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new VeFloorStaking(floor, address(this));

        // Create our {VaultFactory}
        vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            vaultImplementation,
            address(floor)
        );

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(strategyRegistry),
            address(floor)
        );

        // Create our Gauge Weight Vote contract
        gaugeWeightVote = new GaugeWeightVote(
            address(collectionRegistry),
            address(vaultFactory),
            address(veFloor),
            address(authorityRegistry),
            address(treasury)
        );

        // Set up our veFloor token
        veFloor = new VeFloorStaking(floor, address(treasury));

        // Create our {FloorWars} contract
        floorWars = new FloorWars(address(treasury), address(veFloor));

        // Create our {EpochManager} contract and assign it to required contracts
        epochManager = new EpochManager();
        floorWars.setEpochManager(address(epochManager));
        veFloor.setEpochManager(address(epochManager));

        epochManager.setContracts(
            address(collectionRegistry),
            address(floorWars),
            address(pricingExecutorMock),
            address(treasury),
            address(vaultFactory),
            address(gaugeWeightVote)
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
        war = floorWars.createFloorWar(1, collections, isErc1155, floorPrices);

        // Move to our next epoch to activate the created war at epoch 1
        epochManager.endEpoch();

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
        assertEq(floorWars.userVotingPower(alice), 100 ether);
        assertEq(floorWars.userVotingPower(bob), 50 ether);
        assertEq(floorWars.userVotingPower(carol), 0 ether);

        vm.prank(alice);
        floorWars.vote(address(1));

        assertEq(floorWars.userVotingPower(alice), 100 ether);
        assertEq(floorWars.userVotingPower(bob), 50 ether);
        assertEq(floorWars.userVotingPower(carol), 0 ether);
    }

    function test_CanGetUserVotesAvailable() external {
        assertEq(floorWars.userVotesAvailable(war, alice), 100 ether);
        assertEq(floorWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(floorWars.userVotesAvailable(war, carol), 0 ether);

        vm.prank(alice);
        floorWars.vote(address(1));

        assertEq(floorWars.userVotesAvailable(war, alice), 0 ether);
        assertEq(floorWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(floorWars.userVotesAvailable(war, carol), 0 ether);

        assertEq(floorWars.userVotesAvailable(war + 1, alice), 100 ether);
        assertEq(floorWars.userVotesAvailable(war + 1, bob), 50 ether);
        assertEq(floorWars.userVotesAvailable(war + 1, carol), 0 ether);
    }

    function test_CanVote1() external {
        vm.prank(alice);
        floorWars.vote(address(1));

        vm.prank(bob);
        floorWars.vote(address(mock721));

        vm.prank(carol);
        floorWars.vote(address(mock1155));
    }

    function test_CanRevote() external {
        vm.startPrank(alice);
        floorWars.vote(address(mock721));
        floorWars.vote(address(mock1155));
        vm.stopPrank();
    }

    function test_CannotVoteOnInvalidWarCollection() external {
        vm.expectRevert('Invalid collection');
        vm.prank(alice);
        floorWars.vote(address(10));
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));
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
        mock1155.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock1155), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(mock1155.balanceOf(address(floorWars), 0), 5);
        assertEq(mock1155.balanceOf(address(floorWars), 1), 3);
        assertEq(mock1155.balanceOf(address(floorWars), 2), 0);

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
        mock721.setApprovalForAll(address(floorWars), true);

        vm.expectRevert('ERC721: caller is not token owner or approved');
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
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

        floorWars.endFloorWar();
    }

    function test_CannotEndPendingFloorWar() external {
        vm.expectRevert('FloorWar has not ended');
        floorWars.endFloorWar();
    }

    function test_CannotEndFloorWarThatDoesNotExist() external {
        vm.expectRevert('FloorWar has not ended');
        floorWars.endFloorWar();
    }

    function test_CannotEndAlreadyEndedFloorWar() external {
        vm.prank(bob);
        floorWars.vote(address(1));

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        vm.expectRevert('FloorWar end already actioned');
        floorWars.endFloorWar();
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        floorWars.exerciseCollectionERC721s{value: 1.35 ether}(war, tokenIds);

        assertEq(mock721.ownerOf(0), address(treasury));
        assertEq(mock721.ownerOf(1), address(treasury));

        // Alice should still have the same ETH amount that she started with, but will have
        // the additional amounts awaiting her in escrow.
        assertEq(address(alice).balance, aliceStartAmount);
        assertEq(floorWars.payments(address(alice)), 0.60 ether + 0.75 ether);

        // Confirm that Alice can then withdraw the payment
        floorWars.withdrawPayments(payable(alice));
        assertEq(address(alice).balance, aliceStartAmount + 0.60 ether + 0.75 ether);
        assertEq(floorWars.payments(address(alice)), 0);
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        vm.expectRevert('Unable to make payment');
        floorWars.exerciseCollectionERC721s{value: 1 ether}(war, tokenIds);
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
        mock1155.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock1155), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        /**
         * From our voting, we should have the following available to the {Treasury}:
         *  - Token #0 - 5x - 0.25
         *  - Token #1 - 3x - 0.35
         *  - Token #1 - 2x - 0.45
         *
         * We want to exercise the following:
         *  - Token #0 - 3x - 0.25
         *  - Token #1 - 3x - 0.35
         *  - Token #1 - 1x - 0.45
         *
         * This should total 1.90 spend and return 3x of Token #0 and 3x of Token #1.
         */

        uint[] memory exerciseTokenIds = new uint[](2);
        exerciseTokenIds[0] = 0;
        exerciseTokenIds[1] = 1;

        uint[] memory exerciseAmounts = new uint[](2);
        exerciseAmounts[0] = 0.8 ether;  // 0.8eth - We have added more than needed to show refund
        exerciseAmounts[1] = 1.5 ether;  // 1.5eth

        floorWars.exerciseCollectionERC1155s{value: 3 ether}(war, exerciseTokenIds, exerciseAmounts);

        assertEq(mock1155.balanceOf(address(floorWars), 0), 2);
        assertEq(mock1155.balanceOf(address(floorWars), 1), 1);

        assertEq(mock1155.balanceOf(address(treasury), 0), 3);
        assertEq(mock1155.balanceOf(address(treasury), 1), 4);

        assertEq(address(alice).balance, aliceStartAmount + 0.75 ether + 1.5 ether);
    }

    function test_CannotExerciseUnknownStakedNft() external {
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        uint[] memory mixedTokenIds = new uint[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.expectRevert('Token is not staked');
        floorWars.exerciseCollectionERC721s{value: 5 ether}(war, mixedTokenIds);

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));

        assertEq(address(alice).balance, aliceStartAmount);
    }

    function test_CannotExerciseStakedNftOfVoteThatDidNotWin() external {
        vm.prank(bob);
        floorWars.vote(address(1));

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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        vm.expectRevert();
        floorWars.exerciseCollectionERC721s(war, tokenIds);

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));

        assertEq(address(alice).balance, aliceStartAmount);
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        assertEq(floorWars.collectionVotes(keccak256(abi.encode(war, address(mock721)))), 1.5 ether);

        vm.expectRevert('FloorWar has not ended');
        vm.prank(alice);
        floorWars.reclaimCollectionNft(war, address(mock721), singleTokenId);

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(2);

        floorWars.endFloorWar();

        vm.startPrank(alice);
        floorWars.reclaimCollectionNft(war, address(mock721), tokenIds);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), alice);
        assertEq(mock721.ownerOf(1), alice);
    }

    function test_aaaCanReclaimStakedNftThatDidNotWinWithinTimelock() external {
        vm.prank(bob);
        floorWars.vote(address(1));

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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        vm.startPrank(alice);
        floorWars.reclaimCollectionNft(war, address(mock721), tokenIds);
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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        // Should only be reclaimable from epoch 2
        epochManager.setCurrentEpoch(1);

        floorWars.endFloorWar();

        vm.startPrank(alice);
        vm.expectRevert('Currently timelocked');
        floorWars.reclaimCollectionNft(war, address(mock721), tokenIds);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));
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
        mock721.setApprovalForAll(address(floorWars), true);

        vm.expectRevert('Exercise percent above 100%');
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();
    }

    function test_CanUpdateCollectionFloorPrice() external {
        // Cast some base votes that should not be manipulated. Bob will cast
        // `50 ether` votes from this transaction.
        vm.prank(bob);
        floorWars.vote(address(mock721));

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
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(address(mock721), tokenIds, amounts, exercisePercents);
        vm.stopPrank();

        bytes32 warCollection = keccak256(abi.encode(war, address(mock721)));

        // Check our collection vote counts with our initial 0.75e token price
        assertEq(floorWars.collectionVotes(warCollection), 50 ether + ((0.75 ether * 125) / 100) + 0.75 ether);
        assertEq(floorWars.collectionNftVotes(warCollection), ((0.75 ether * 125) / 100) + 0.75 ether);

        // 0.75 ether => 1 ether
        floorWars.updateCollectionFloorPrice(address(mock721), 1 ether);

        // Check our collection vote counts
        assertAlmostEqual(floorWars.collectionVotes(warCollection), 50 ether + ((1 ether * 125) / 100) + 1 ether, 1);
        assertAlmostEqual(floorWars.collectionNftVotes(warCollection), ((1 ether * 125) / 100) + 1 ether, 1);

        // 1 ether => 0.5 ether
        floorWars.updateCollectionFloorPrice(address(mock721), 1 ether);

        // Check our collection vote counts
        assertAlmostEqual(floorWars.collectionVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);
        assertAlmostEqual(floorWars.collectionNftVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);

        // 0.5 ether => 0.5 ether
        floorWars.updateCollectionFloorPrice(address(mock721), 0.5 ether);

        // Check our collection vote counts
        assertAlmostEqual(floorWars.collectionVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);
        assertAlmostEqual(floorWars.collectionNftVotes(warCollection), ((0.5 ether * 125) / 100) + 0.5 ether, 1);
    }

    function test_CannotUpdateCollectionFloorPriceToZero() external {
        vm.expectRevert('Invalid floor price');
        floorWars.updateCollectionFloorPrice(address(mock721), 0);
    }

    function test_CannotUpdateCollectionFloorPriceToUnknownCollection() external {
        vm.expectRevert('Invalid collection');
        floorWars.updateCollectionFloorPrice(address(6), 1 ether);
    }

    function test_CanCalculateNftVotingPower() external {
        assertEq(floorWars.nftVotingPower(1 ether, 0),   2.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 10),  1.90 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 20),  1.80 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 30),  1.70 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 40),  1.60 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 50),  1.50 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 60),  1.40 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 70),  1.30 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 80),  1.20 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 90),  1.10 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 100), 1.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 110), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 120), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 130), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 140), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 150), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 160), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 170), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 180), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 190), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 200), 0.00 ether);
    }

}
