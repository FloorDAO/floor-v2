// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FloorWars} from '@floor/voting/FloorWars.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {Treasury} from '@floor/Treasury.sol';

import {ERC1155Mock} from '../mocks/erc/ERC1155Mock.sol';
import {ERC721Mock} from '../mocks/erc/ERC721Mock.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract FloorWarsTest is FloorTest {

    // Contract references to be deployed
    FLOOR floor;
    FloorWars floorWars;
    VeFloorStaking veFloor;

    address treasury;

    address alice;
    address bob;
    address carol;

    uint war;

    ERC721Mock mock721;
    ERC1155Mock mock1155;

    constructor() {
        // Deploy our FLOOR token
        floor = new FLOOR(address(authorityRegistry));

        // Set up a {Treasury} mock
        treasury = address(9);

        // Set up our veFloor token
        veFloor = new VeFloorStaking(floor, treasury);

        // Create our {FloorWars} contract
        floorWars = new FloorWars(treasury, address(veFloor));

        // Create some mock tokens
        mock721 = new ERC721Mock();
        mock1155 = new ERC1155Mock();

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
        floorPrices[2] = 0.25 ether;
        floorPrices[3] = 0.5 ether;
        floorPrices[4] = 0.5 ether;

        // Set up a war
        war = floorWars.createFloorWar(0, collections, isErc1155, floorPrices);

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

        // Fund our {FloorWars} contract so that it can exercise tokens in tests
        vm.deal(address(floorWars), 100 ether);
    }

    function test_CanGetUserVotingPower() external {
        assertEq(floorWars.userVotingPower(alice), 100 ether);
        assertEq(floorWars.userVotingPower(bob), 50 ether);
        assertEq(floorWars.userVotingPower(carol), 0 ether);

        vm.prank(alice);
        floorWars.vote(war, address(1));

        assertEq(floorWars.userVotingPower(alice), 100 ether);
        assertEq(floorWars.userVotingPower(bob), 50 ether);
        assertEq(floorWars.userVotingPower(carol), 0 ether);
    }

    function test_CanGetUserVotesAvailable() external {
        assertEq(floorWars.userVotesAvailable(war, alice), 100 ether);
        assertEq(floorWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(floorWars.userVotesAvailable(war, carol), 0 ether);

        vm.prank(alice);
        floorWars.vote(war, address(1));

        assertEq(floorWars.userVotesAvailable(war, alice), 0 ether);
        assertEq(floorWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(floorWars.userVotesAvailable(war, carol), 0 ether);

        assertEq(floorWars.userVotesAvailable(war + 1, alice), 100 ether);
        assertEq(floorWars.userVotesAvailable(war + 1, bob), 50 ether);
        assertEq(floorWars.userVotesAvailable(war + 1, carol), 0 ether);
    }

    function test_CanVote() external {
        vm.prank(alice);
        floorWars.vote(war, address(1));

        vm.prank(bob);
        floorWars.vote(war, address(mock721));

        vm.prank(carol);
        floorWars.vote(war, address(mock1155));
    }

    function test_CanRevote() external {
        vm.startPrank(alice);
        floorWars.vote(war, address(mock721));
        floorWars.vote(war, address(mock1155));
        vm.stopPrank();
    }

    function test_CannotVoteOnInvalidWarIndex() external {
        vm.expectRevert('Invalid index');
        vm.prank(alice);
        floorWars.vote(war + 1, address(1));
    }

    function test_CannotVoteOnInvalidWarCollection() external {
        vm.expectRevert('Invalid collection');
        vm.prank(alice);
        floorWars.vote(war, address(10));
    }

    function test_CanVoteWithCollectionNft721() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));
        assertEq(mock721.ownerOf(2), alice);
    }

    function test_CanVoteWithCollectionNft1155() external {
        // TODO
    }

    function test_CannotVoteWithInvalidCollectionNft() external {
        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = 10;

        uint[] memory exercisePrices = new uint[](1);
        exercisePrices[0] = 0.75 ether;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);

        vm.expectRevert('ERC721: caller is not token owner or approved');
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        assertEq(mock721.ownerOf(10), carol);
    }

    function test_CanCreateFloorWar() external {
        // This is tested in the instantiation of the test
    }

    function test_CanEndFloorWar(uint currentEpoch) external {
        vm.assume(currentEpoch > 0);
        vm.assume(currentEpoch <= 10);
        floorWars.setCurrentEpoch(currentEpoch);

        floorWars.endFloorWar(0);
    }

    function test_CannotEndPendingFloorWar() external {
        vm.expectRevert('FloorWar has not ended');
        floorWars.endFloorWar(0);
    }

    function test_CannotEndFloorWarThatDoesNotExist() external {
        vm.expectRevert('Invalid index');
        floorWars.endFloorWar(1);
    }

    function test_CannotEndAlreadyEndedFloorWar() external {
        floorWars.setCurrentEpoch(1);
        floorWars.endFloorWar(0);

        vm.expectRevert('FloorWar end already actioned');
        floorWars.endFloorWar(0);
    }

    function test_CanExerciseStakedNft() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        uint aliceStartAmount = address(alice).balance;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        floorWars.setCurrentEpoch(1);
        floorWars.endFloorWar(war);

        vm.prank(alice);
        floorWars.exerciseCollectionNfts(war, address(mock721), tokenIds);

        assertEq(mock721.ownerOf(0), treasury);
        assertEq(mock721.ownerOf(1), treasury);

        assertEq(address(alice).balance, aliceStartAmount + 0.75 ether + 0.85 ether);
    }

    function test_CannotExerciseUnknownStakedNft() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        uint aliceStartAmount = address(alice).balance;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        floorWars.setCurrentEpoch(1);
        floorWars.endFloorWar(war);

        uint[] memory mixedTokenIds = new uint[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.expectRevert('Token is not staked');
        floorWars.exerciseCollectionNfts(war, address(mock721), mixedTokenIds);

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));

        assertEq(address(alice).balance, aliceStartAmount);
    }

    function test_CannotExerciseStakedNftOfVoteThatDidNotWin() external {
        vm.prank(bob);
        floorWars.vote(war, address(1));

        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        uint aliceStartAmount = address(alice).balance;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        floorWars.setCurrentEpoch(1);
        floorWars.endFloorWar(war);

        vm.expectRevert();
        floorWars.exerciseCollectionNfts(war, address(mock721), tokenIds);

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));

        assertEq(address(alice).balance, aliceStartAmount);
    }

    function test_CanReclaimStakedNftInSameEpoch() external {
        uint[] memory singleTokenId = new uint[](1);

        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.75 ether;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        assertEq(floorWars.collectionVotes(keccak256(abi.encode(war, address(mock721)))), 1.5 ether);

        singleTokenId[0] = 0;
        vm.prank(alice);
        floorWars.reclaimCollectionNft(war, address(mock721), singleTokenId);

        assertEq(mock721.ownerOf(0), alice);
        assertEq(mock721.ownerOf(1), address(floorWars));

        assertEq(floorWars.collectionVotes(keccak256(abi.encode(war, address(mock721)))), 0.75 ether);

        singleTokenId[0] = 1;
        vm.prank(alice);
        floorWars.reclaimCollectionNft(war, address(mock721), singleTokenId);

        assertEq(floorWars.collectionVotes(keccak256(abi.encode(war, address(mock721)))), 0);

        assertEq(mock721.ownerOf(0), alice);
        assertEq(mock721.ownerOf(1), alice);
    }

    function test_CanReclaimStakedNft() external {
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        floorWars.setCurrentEpoch(2);
        floorWars.endFloorWar(war);

        vm.startPrank(alice);
        floorWars.reclaimCollectionNft(war, address(mock721), tokenIds);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), alice);
        assertEq(mock721.ownerOf(1), alice);
    }

    function test_CanReclaimStakedNftThatDidNotWinWithinTimelock() external {
        vm.prank(bob);
        floorWars.vote(war, address(1));

        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        floorWars.setCurrentEpoch(1);
        floorWars.endFloorWar(war);

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

        uint[] memory exercisePrices = new uint[](2);
        exercisePrices[0] = 0.75 ether;
        exercisePrices[1] = 0.85 ether;

        vm.startPrank(alice);
        mock721.setApprovalForAll(address(floorWars), true);
        floorWars.voteWithCollectionNft(war, address(mock721), tokenIds, exercisePrices);
        vm.stopPrank();

        // Should only be reclaimable from epoch 2
        floorWars.setCurrentEpoch(1);
        floorWars.endFloorWar(war);

        vm.startPrank(alice);
        vm.expectRevert('Currently timelocked');
        floorWars.reclaimCollectionNft(war, address(mock721), tokenIds);
        vm.stopPrank();

        assertEq(mock721.ownerOf(0), address(floorWars));
        assertEq(mock721.ownerOf(1), address(floorWars));
    }

    function test_CanCalculateNftVotingPower() external {
        assertEq(floorWars.nftVotingPower(1 ether, 0.0 ether), 2.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.1 ether), 1.90 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.2 ether), 1.80 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.3 ether), 1.70 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.4 ether), 1.60 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.5 ether), 1.25 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.6 ether), 1.20 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.7 ether), 1.10 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.8 ether), 1.04 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 0.9 ether), 1.01 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.0 ether), 1.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.1 ether), 0.99 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.2 ether), 0.96 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.3 ether), 0.90 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.4 ether), 0.80 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.5 ether), 0.75 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.6 ether), 0.40 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.7 ether), 0.30 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.8 ether), 0.20 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 1.9 ether), 0.10 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 2.0 ether), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 2.1 ether), 0.00 ether);
        assertEq(floorWars.nftVotingPower(1 ether, 2.2 ether), 0.00 ether);
    }

}
