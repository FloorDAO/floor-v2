// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {PricingExecutorMock} from '../mocks/PricingExecutor.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {FloorNft} from '@floor/tokens/FloorNft.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager, EpochTimelocked, NoPricingExecutorSet} from '@floor/EpochManager.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, Treasury} from '@floor/Treasury.sol';

import {ERC1155Mock} from '../mocks/erc/ERC1155Mock.sol';
import {ERC721Mock} from '../mocks/erc/ERC721Mock.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract NewCollectionWarsTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    // Store our max epoch index
    uint internal constant MAX_EPOCH_INDEX = 3;

    /// Sent when a Collection Addition War is started
    event CollectionAdditionWarStarted(uint warIndex);

    /// Sent when a Collection Addition War ends
    event CollectionAdditionWarEnded(uint warIndex, address collection);

    /// Sent when a Collection Addition War is created
    event CollectionAdditionWarCreated(uint epoch, address[] collections, uint[] floorPrices);

    /// Sent when a collection NFT is staked to vote
    event NftVoteCast(address sender, uint war, address collection, uint collectionVotes, uint collectionNftVotes);

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
    StrategyRegistry strategyRegistry;

    address alice;
    address bob;
    address carol;
    address david;
    address ethan;

    uint war;

    ERC721Mock mock721;
    ERC1155Mock mock1155;

    address[] collections;
    bool[] isErc1155;
    uint[] floorPrices;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new VeFloorStaking(floor, address(this));

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
        treasury.setEpochManager(address(epochManager));

        epochManager.setContracts(
            address(newCollectionWars),
            address(0) // Vote Market not needed for these tests
        );

        // Set our war contracts against our staking contract
        veFloor.setVotingContracts(address(newCollectionWars), address(sweepWars));

        // Create some mock tokens
        mock721 = new ERC721Mock();
        mock1155 = new ERC1155Mock();

        // Map some users to simpler addresses
        (alice, bob, carol, david, ethan) = (users[0], users[1], users[2], users[3], users[4]);

        // Give our test users a selection of ERC721 and ERC1155 tokens
        for (uint i; i < 10; ++i) {
            mock721.mint(alice, i);
            mock1155.mint(alice, i, 10, bytes(''));

            mock721.mint(carol, i + 10);
            mock1155.mint(carol, i + 10, 10, bytes(''));
        }

        // Register our epoch end trigger that stores our treasury sweep
        RegisterSweepTrigger registerSweepTrigger = new RegisterSweepTrigger(
            address(newCollectionWars),
            address(pricingExecutorMock),
            address(strategyFactory),
            address(treasury),
            address(sweepWars)
        );
        registerSweepTrigger.setEpochManager(address(epochManager));
        epochManager.setEpochEndTrigger(address(registerSweepTrigger), true);

        // Grant required roles for our trigger to work
        /* Allows our trigger to register a sweep in the {Treasury} */
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(registerSweepTrigger));

        /* Allows our trigger to take a snapshot of the strategies */
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(registerSweepTrigger));

        /* Allows our trigger and the epoch manager to end a floor war */
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), address(registerSweepTrigger));
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), address(epochManager));

        // Grant Alice and Bob plenty of veFLOOR tokens to play with
        floor.mint(alice, 200 ether);
        floor.mint(bob, 50 ether);
        floor.mint(david, 200 ether);
        floor.mint(ethan, 200 ether);

        vm.startPrank(alice);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, MAX_EPOCH_INDEX);
        vm.stopPrank();

        vm.startPrank(bob);
        floor.approve(address(veFloor), 50 ether);
        veFloor.deposit(50 ether, MAX_EPOCH_INDEX);
        vm.stopPrank();

        vm.startPrank(david);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, MAX_EPOCH_INDEX);
        vm.stopPrank();

    }

    function test_CanGetUserVotingPower() external defaultNewCollectionWar {
        assertEq(newCollectionWars.userVotingPower(alice), 100 ether);
        assertEq(newCollectionWars.userVotingPower(bob), 50 ether);
        assertEq(newCollectionWars.userVotingPower(carol), 0 ether);

        vm.prank(alice);
        newCollectionWars.vote(address(1));

        assertEq(newCollectionWars.userVotingPower(alice), 100 ether);
        assertEq(newCollectionWars.userVotingPower(bob), 50 ether);
        assertEq(newCollectionWars.userVotingPower(carol), 0 ether);
    }

    function test_CanGetUserVotesAvailable() external defaultNewCollectionWar {
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

    function test_CanVote() external defaultNewCollectionWar {
        // 100 eth of vote power assigned
        vm.prank(alice);
        newCollectionWars.vote(address(1));

        // 50 eth of vote power assigned
        vm.prank(bob);
        newCollectionWars.vote(address(mock721));

        // Even though Carol has no voting power available, she is still able to vote but
        // we see no power assigned. Is this as expected?
        vm.prank(carol);
        newCollectionWars.vote(address(mock1155));

        // Confirm our voting levels across users
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 50 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, carol), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, carol)), 0);

        // Confirm our vote powers
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(1))), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 50 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);

        // Confirm the collections our system understands our users to have voted vote
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(1));
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, bob)), address(mock721));
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, carol)), address(mock1155));
    }

    /**
     * We need to ensure a user can stake for different periods of time and that the
     * amount of votes cast against the collection will vary. This will also need to make
     * sure that when votes are revoked that it works correctly.
     */
    function test_CanVoteWithVaryingPower(uint depositAmount, uint8 depositLock) external defaultNewCollectionWar {
        // Ensure we use a valid deposit epoch index
        vm.assume(depositLock <= MAX_EPOCH_INDEX);
        vm.assume(depositAmount >= 1 ether);
        vm.assume(depositAmount <= 100000 ether);

        // Mint enough floor to the test user
        floor.mint(ethan, depositAmount);

        // Stake the floor against a deposit lock duration
        vm.startPrank(ethan);
        floor.approve(address(veFloor), depositAmount);
        veFloor.deposit(depositAmount, depositLock);
        vm.stopPrank();

        // Confirm the voting power held by the user
        uint expectedVotes = uint(depositAmount) * veFloor.LOCK_PERIODS(depositLock) / veFloor.LOCK_PERIODS(MAX_EPOCH_INDEX);
        assertEq(newCollectionWars.userVotingPower(ethan), expectedVotes);
        assertEq(newCollectionWars.userVotesAvailable(war, ethan), expectedVotes);
    }

    function test_CanRevote() external defaultNewCollectionWar {
        vm.startPrank(alice);

        // Confirm our user's current vote position and the votes attributed to
        // each collection
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 0);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(1))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(0));
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, bob)), address(0));

        // Cast our vote on the first collection
        newCollectionWars.vote(address(mock721));

        // Confirm the updated vote standings
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(1))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock721));
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, bob)), address(0));

        // Cast another vote against the second collection, which should remove
        // the previous vote and replace it.
        newCollectionWars.vote(address(mock1155));

        // Make an additional deposit, which will increase our vote power but not be
        // reflected in any votes as they are not yet cast.
        floor.approve(address(veFloor), 50 ether);
        veFloor.deposit(50 ether, MAX_EPOCH_INDEX);

        // Confirm that the existing vote levels do not change
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(1))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 100 ether);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock1155));
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, bob)), address(0));

        // Cast another vote against the second collection, which should update
        // the number of votes to be the new vote power.
        newCollectionWars.vote(address(mock1155));

        // Confirm the updated vote standings
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 150 ether);
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(1))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 150 ether);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock1155));
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, bob)), address(0));

        vm.stopPrank();
    }

    /**
     * When the initial vote is cast, it will assign a war collection to the user. We need
     * to ensure that when we enter the next, or any subsequent epoch, that the user will
     * be able to update their vote without a revert.
     *
     * Once a war has finished, their vote should no longer be allocated to that collection
     * and would need to be recast. This will also be covered in this test.
     */
    function test_CanRevoteInNextEpoch() external defaultNewCollectionWar {
        // Set up an addition war that will occur in the next epoch. It will consist
        // of the same collections as the existing one. We are still, however, currently
        // in our first war until we end the epoch later in this test.
        uint nextWar = newCollectionWars.createFloorWar(epochManager.currentEpoch() + 1, collections, isErc1155, floorPrices);

        // Cast our vote on the first collection in the first war
        vm.prank(alice);
        newCollectionWars.vote(address(mock721));

        // Confirm our user's current vote position and the votes attributed to
        // each collection.
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotesAvailable(nextWar, alice), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(nextWar, alice)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(nextWar, address(mock721))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(nextWar, address(mock1155))), 0);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock721));
        assertEq(newCollectionWars.userCollectionVote(_warUser(nextWar, alice)), address(0));

        // Move to our next epoch to activate the next war and finish the first one
        epochManager.endEpoch();

        // We should see that the vote values are still the same
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotesAvailable(nextWar, alice), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(nextWar, alice)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(nextWar, address(mock721))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(nextWar, address(mock1155))), 0);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock721));
        assertEq(newCollectionWars.userCollectionVote(_warUser(nextWar, alice)), address(0));

        // The user now casts their new vote, voting for another collection
        vm.prank(alice);
        newCollectionWars.vote(address(mock1155));

        // We can now see the new user's vote hitting the `nextWar` values
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotesAvailable(nextWar, alice), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(nextWar, alice)), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(nextWar, address(mock721))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(nextWar, address(mock1155))), 100 ether);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock721));
        assertEq(newCollectionWars.userCollectionVote(_warUser(nextWar, alice)), address(mock1155));
    }

    function test_CanRevokeVotes() external defaultNewCollectionWar {
        vm.startPrank(alice);

        // Cast our vote on the first collection
        newCollectionWars.vote(address(mock721));

        // Confirm the updated vote standings
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 0);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 100 ether);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock721));

        vm.stopPrank();

        // Revoke the user's votes
        newCollectionWars.revokeVotes(alice);

        // Confirm that the votes have been revoked
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 100 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 0);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock721))), 0);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(0));

        vm.startPrank(alice);

        // Cast another vote against the second collection, which should remove
        // the previous vote and replace it.
        newCollectionWars.vote(address(mock1155));

        // Make an additional deposit, which will increase our vote power but not be
        // reflected in any votes as they are not yet cast.
        floor.approve(address(veFloor), 50 ether);
        veFloor.deposit(50 ether, MAX_EPOCH_INDEX);

        // Confirm that the existing vote levels do not change
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 100 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 100 ether);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(mock1155));

        vm.stopPrank();

        newCollectionWars.revokeVotes(alice);

        // Confirm the updated vote standings
        assertEq(newCollectionWars.userVotesAvailable(war, alice), 150 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, alice)), 0 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, address(mock1155))), 0);
        assertEq(newCollectionWars.userCollectionVote(_warUser(war, alice)), address(0));
    }

    function test_CanRevokeVotesWithoutUserHavingCastAVote() external defaultNewCollectionWar {
        // Check bob's initial vote power
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 0 ether);

        // We just need to confirm that none of these revert
        newCollectionWars.revokeVotes(bob);

        // Confirm that vote power has not changed
        assertEq(newCollectionWars.userVotesAvailable(war, bob), 50 ether);
        assertEq(newCollectionWars.userVotes(_warUser(war, bob)), 0 ether);
    }

    function test_CannotRevokeVotesWithoutRole() external {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.VOTE_MANAGER()));
        newCollectionWars.revokeVotes(bob);
        vm.stopPrank();
    }

    function test_CannotVoteOnInvalidWarCollection() external defaultNewCollectionWar {
        vm.expectRevert('Invalid collection');
        vm.prank(alice);
        newCollectionWars.vote(address(10));
    }

    function test_CannotVoteWhenWarIsNotActive() external {
        vm.expectRevert('No war currently running');
        vm.prank(alice);
        newCollectionWars.vote(address(1));
    }

    function test_CanCreateFloorWar(uint128 epoch, uint8 indexes) external {
        // Ensure that it is below the limit of a uint128, as we add 1 to this value in
        // a later test. We also cannot create in the current epoch.
        vm.assume(epoch > epochManager.currentEpoch());
        vm.assume(epoch < type(uint128).max);

        // We want to have between 2 and 10 collections
        vm.assume(indexes >= 2 && indexes <= 10);

        // Set up our test collections and their relative information
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(indexes);

        // Confirm that we emit the expected event
        vm.expectEmit(true, true, false, true, address(newCollectionWars));
        emit CollectionAdditionWarCreated(epoch, collections, floorPrices);

        // Create our floor war
        uint warIndex = newCollectionWars.createFloorWar(epoch, collections, isErc1155, floorPrices);

        // Confirm our expected war index. The global was is set up as 1 as the first (as 0 is
        // skipped).
        assertEq(warIndex, 1);

        // Confirm that we initially have no winner attached
        assertEq(newCollectionWars.floorWarWinner(warIndex), address(0));

        // Confirm that a number of mappings are set up correctly against our collections
        for (uint i; i < collections.length; ++i) {
            bytes32 hash = _warCollection(warIndex, collections[i]);
            assertEq(newCollectionWars.collectionSpotPrice(hash), floorPrices[i]);
            assertEq(newCollectionWars.collectionEpochLock(hash), epoch + 1);
            assertEq(newCollectionWars.is1155(collections[i]), isErc1155[i]);
        }

        // Confirm that our epoch manager has a mapping of the epoch to the war index
        assertEq(epochManager.collectionEpochs(epoch), warIndex);
    }

    function test_CannotCreateFloorWarsWithoutMatchingParameterCounts(uint8 a, uint8 b, uint8 c) external {
        // Ensure that we have at least 2 collections to avoid an "Insufficient collections" error
        vm.assume(a > 1);

        // Ensure that at least one of our parameter counts don't match
        vm.assume(a != b || a != c || b != c);

        // Set up a collections array
        collections = new address[](a);
        isErc1155 = new bool[](b);
        floorPrices = new uint[](c);

        for (uint i = 1; i <= a; ++i) { collections[i - 1] = address(uint160(i)); }
        for (uint i = 1; i <= b; ++i) { isErc1155[i - 1] = (i % 3 == 0); }
        for (uint i = 1; i <= c; ++i) { floorPrices[i - 1] = i * 1 ether; }

        // Set up a war
        vm.expectRevert('Incorrect parameter counts');
        newCollectionWars.createFloorWar(1, collections, isErc1155, floorPrices);
    }

    function test_CannotCreateFloorWarsBeforeNextEpoch(uint currentEpoch, uint createEpoch) external {
        vm.assume(createEpoch <= currentEpoch);

        setCurrentEpoch(address(epochManager), currentEpoch);

        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(2);

        // Set up a war
        vm.expectRevert('Floor War scheduled too soon');
        newCollectionWars.createFloorWar(createEpoch, collections, isErc1155, floorPrices);
    }

    function test_CannotCreateFloorWarsWithoutAtLeastTwoCollections(uint epoch, uint8 indexes) external {
        vm.assume(epoch >= 1);
        vm.assume(indexes == 0 || indexes == 1);

        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(indexes);

        vm.expectRevert('Insufficient collections');
        newCollectionWars.createFloorWar(epoch, collections, isErc1155, floorPrices);
    }

    function test_CannotCreateFloorWarsOverExistingFloorWars(uint128 epoch) external {
        // The epoch must be above the current, as a war must be created in the future
        vm.assume(epoch > epochManager.currentEpoch());

        // Set up sufficient collection data
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);

        // Create our floor war, which should be successful
        newCollectionWars.createFloorWar(epoch, collections, isErc1155, floorPrices);

        // When we try and create another this should fail as we cannot overwrite
        vm.expectRevert('War already exists at epoch');
        newCollectionWars.createFloorWar(epoch, collections, isErc1155, floorPrices);
    }

    function test_CanEndFloorWarWithClearWinner() external {
        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(2, collections, isErc1155, floorPrices);

        // Move to the correct epoch so that we can vote
        setCurrentEpoch(address(epochManager), 2);

        // Start our floor war
        vm.prank(address(epochManager));
        newCollectionWars.startFloorWar(warIndex);

        // Cast a vote
        vm.prank(alice);
        newCollectionWars.vote(collections[1]);

        // Confirm that our war has closed with the expected data
        assertEndFloorWarOutput(collections[1], warIndex);
    }

    function test_CanEndFloorWarWithDrawnWinner() external {
        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(2, collections, isErc1155, floorPrices);

        // Move to the correct epoch
        setCurrentEpoch(address(epochManager), 2);

        // Start our floor war
        vm.prank(address(epochManager));
        newCollectionWars.startFloorWar(warIndex);

        // Vote with Alice and David, who both have the same vote power
        vm.prank(alice);
        newCollectionWars.vote(collections[1]);
        vm.prank(david);
        newCollectionWars.vote(collections[2]);

        // In this unusual circumstance, the winner is the first collection in the array
        assertEndFloorWarOutput(collections[1], warIndex);
    }

    function test_CanEndFloorWarWithNoVotes() external {
        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(2, collections, isErc1155, floorPrices);

        // Move to the correct epoch
        setCurrentEpoch(address(epochManager), 2);

        // Start our floor war
        vm.prank(address(epochManager));
        newCollectionWars.startFloorWar(warIndex);

        // In this instance, no collection in the array will be voted in
        assertEndFloorWarOutput(address(0), warIndex);
    }

    function test_CanEndFloorWarInAnySubsequentEpoch(uint128 warEpoch, uint128 endingEpoch) external {
        vm.assume(warEpoch > 1);
        vm.assume(warEpoch < type(uint128).max / 2);
        vm.assume(endingEpoch > warEpoch);

        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(warEpoch, collections, isErc1155, floorPrices);

        // Move to the correct epoch
        setCurrentEpoch(address(epochManager), warEpoch);

        // Start our floor war
        vm.prank(address(epochManager));
        newCollectionWars.startFloorWar(warIndex);

        // Cast a vote
        vm.prank(alice);
        newCollectionWars.vote(collections[1]);

        setCurrentEpoch(address(epochManager), endingEpoch);

        assertEndFloorWarOutput(collections[1], warIndex);
    }

    function assertEndFloorWarOutput(address expectedWinner, uint warIndex) internal {
        // Check event fired
        vm.expectEmit(true, true, false, true, address(newCollectionWars));
        emit CollectionAdditionWarEnded(warIndex, expectedWinner);

        // Get the floor information before is ends
        (uint currentWarIndex, uint currentWarStartEpoch) = newCollectionWars.currentWar();
        assertEq(warIndex, currentWarIndex);

        vm.prank(address(epochManager));
        address winner = newCollectionWars.endFloorWar();

        // Check address response
        assertEq(winner, expectedWinner);

        // Check the stored `floorWarWinner`
        assertEq(newCollectionWars.floorWarWinner(warIndex), expectedWinner);

        // The epoch will only be increased if we have a winner
        if (expectedWinner != address(0)) {
            // Check `collectionEpochLock`
            uint winningCollectionEpochLock = newCollectionWars.collectionEpochLock(
                keccak256(abi.encode(warIndex, expectedWinner))
            );

            assertEq(winningCollectionEpochLock, currentWarStartEpoch + 3);
        }

        // Check that `currentWar` is closed
        (currentWarIndex, currentWarStartEpoch) = newCollectionWars.currentWar();
        assertEq(currentWarIndex, 0);
        assertEq(currentWarStartEpoch, 0);
    }

    function test_CannotEndFloorWarWithoutPermissions() external {
        // Make our call as a user without permissions
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.COLLECTION_MANAGER()));
        newCollectionWars.endFloorWar();
        vm.stopPrank();
    }

    function test_CannotEndFloorWarThatDoesNotExist() external {
        // This will end the existing war
        epochManager.endEpoch();

        // We then try to end another floor war, but none should exist
        vm.expectRevert('No war currently running');
        vm.prank(address(epochManager));
        newCollectionWars.endFloorWar();
    }

    function test_CanUpdateCollectionFloorPrices() external defaultNewCollectionWar {
        // Set our vote options contract to an arbritrary address, so we can mock a call
        address validCaller = address(1);
        newCollectionWars.setOptionsContract(validCaller);

        // Loop through all collections to give them option votes
        for (uint i; i < collections.length; ++i) {
            // Determine the number of votes to assign
            uint optionVotes = (i + 1) * 1 ether;

            vm.prank(validCaller);
            newCollectionWars.optionVote(validCaller, war, collections[i], optionVotes);

            // Determine the hash of the collection for the war
            bytes32 hash = _warCollection(war, collections[i]);

            // Confirm the start price is as expected
            assertEq(newCollectionWars.collectionSpotPrice(hash), floorPrices[i]);
        }

        // Now that the prices have been altered, our vote amounts should be different on the
        // ones that we updated.
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[0])), 1 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[1])), 2 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[2])), 3 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[3])), 4 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[4])), 5 ether);

        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[0])), 1 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[1])), 2 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[2])), 3 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[3])), 4 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[4])), 5 ether);

        // Update the collection floor price and confirm the that is has updated correctly
        newCollectionWars.updateCollectionFloorPrice(collections[0], 1 ether);  // Set to the same
        newCollectionWars.updateCollectionFloorPrice(collections[2], 0.5 ether);  // Set to half
        newCollectionWars.updateCollectionFloorPrice(collections[4], 1 ether);  // Set to double

        // Confirm the collection prices we expect
        assertEq(newCollectionWars.collectionSpotPrice(_warCollection(war, collections[0])), 1 ether);
        assertEq(newCollectionWars.collectionSpotPrice(_warCollection(war, collections[1])), 0.75 ether);
        assertEq(newCollectionWars.collectionSpotPrice(_warCollection(war, collections[2])), 0.5 ether);
        assertEq(newCollectionWars.collectionSpotPrice(_warCollection(war, collections[3])), 0.5 ether);
        assertEq(newCollectionWars.collectionSpotPrice(_warCollection(war, collections[4])), 1 ether);

        // Now that the prices have been altered, our vote amounts should be different on the
        // ones that we updated.
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[0])), 1 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[1])), 2 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[2])), 1.5 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[3])), 4 ether);
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[4])), 10 ether);

        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[0])), 1 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[1])), 2 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[2])), 1.5 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[3])), 4 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[4])), 10 ether);
    }

    function test_CannotUpdateCollectionFloorPriceIfWarNotRunning(address collection, uint newFloorPrice) external {
        // Ensure that we don't have a zero value floor price, as this would revert
        vm.assume(newFloorPrice > 0);

        vm.expectRevert('No war currently running');
        newCollectionWars.updateCollectionFloorPrice(collection, newFloorPrice);
    }

    function test_CannotUpdateCollectionFloorPriceToZero() external {
        vm.expectRevert('Invalid floor price');
        newCollectionWars.updateCollectionFloorPrice(address(mock721), 0);
    }

    function test_CannotUpdateCollectionFloorPriceToUnknownCollection() external defaultNewCollectionWar {
        vm.expectRevert('Invalid collection');
        newCollectionWars.updateCollectionFloorPrice(address(6), 1 ether);
    }

    function test_CanStartFloorWar(uint128 startEpoch) external {
        // We cannot schedule on zero epoch, as this is the current epoch
        vm.assume(startEpoch > 0);

        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(startEpoch, collections, isErc1155, floorPrices);

        // Move to the correct epoch
        setCurrentEpoch(address(epochManager), startEpoch);

        // Check the start event
        vm.expectEmit(true, true, false, true, address(newCollectionWars));
        emit CollectionAdditionWarStarted(warIndex);

        // Start our floor war
        vm.prank(address(epochManager));
        newCollectionWars.startFloorWar(warIndex);

        // Confirm war start
        (uint index, uint warStartEpoch) = newCollectionWars.currentWar();
        assertEq(index, warIndex);
        assertEq(startEpoch, warStartEpoch);
    }

    function test_CannotStartFloorWarIfAlreadyRunning() external {
        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(2, collections, isErc1155, floorPrices);

        // Move to the correct epoch
        setCurrentEpoch(address(epochManager), 2);

        // Start our floor war
        vm.startPrank(address(epochManager));
        newCollectionWars.startFloorWar(warIndex);

        // Try and start the floor war again, but we should now revert
        vm.expectRevert('War currently running');
        newCollectionWars.startFloorWar(warIndex);

        vm.stopPrank();
    }

    function test_CannotStartFloorWarWithoutPermissions() external {
        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(2, collections, isErc1155, floorPrices);

        // Move to the correct epoch
        setCurrentEpoch(address(epochManager), 2);

        // Start our floor war
        vm.expectRevert('Only EpochManager can call');
        newCollectionWars.startFloorWar(warIndex);
    }

    function test_CannotStartFloorWarAtInvalidEpoch(uint startEpoch, uint lateEpoch) external {
        vm.assume(startEpoch > 1);
        vm.assume(lateEpoch > startEpoch);

        // Create our floor war with 3 collections
        (collections, isErc1155, floorPrices) = _createFloorWarsParameters(3);
        uint warIndex = newCollectionWars.createFloorWar(startEpoch, collections, isErc1155, floorPrices);

        setCurrentEpoch(address(epochManager), lateEpoch);

        // Try and start a war that is already started
        vm.startPrank(address(epochManager));
        vm.expectRevert('Invalid war set to start');
        newCollectionWars.startFloorWar(warIndex);
        vm.stopPrank();
    }

    function test_CannotStartFloorWarThatDoesNotExist(uint warIndex) external {
        vm.assume(warIndex >= 1);

        vm.startPrank(address(epochManager));
        vm.expectRevert('Invalid war set to start');
        newCollectionWars.startFloorWar(warIndex);
        vm.stopPrank();
    }

    function test_CanSetOptionsContract(address _contract) external {
        // Confirm our starting contract address
        assertEq(address(newCollectionWars.newCollectionWarOptions()), address(0));

        // Update the options contract and confirm that it correctly saved
        newCollectionWars.setOptionsContract(_contract);
        assertEq(address(newCollectionWars.newCollectionWarOptions()), _contract);
    }

    function test_CannotSetOptionsContractWithoutPermissions(address _contract) external {
        vm.startPrank(alice);
        vm.expectRevert('Ownable: caller is not the owner');
        newCollectionWars.setOptionsContract(_contract);
        vm.stopPrank();
    }

    function test_CanDetectIsCollectionInWar() external defaultNewCollectionWar {
        for (uint i; i < collections.length; i++) {
            bytes32 validHash = _warCollection(war, collections[i]);
            bytes32 invalidHash = _warCollection(war + 1, collections[i]);

            // Confirm collections that are in the war
            assertTrue(newCollectionWars.isCollectionInWar(validHash));

            // Confirm collections aren't flagged in an incorrect war
            assertFalse(newCollectionWars.isCollectionInWar(invalidHash));
        }

        // Confirm some collections that are not in the existing war
        bytes32 unknownCollectionHash = _warCollection(war, address(123));
        assertFalse(newCollectionWars.isCollectionInWar(unknownCollectionHash));
    }

    function test_CanVoteWithOption(uint96 votesA, uint96 votesB, uint96 votesC) external defaultNewCollectionWar {
        // Set our valid caller address
        address validCaller = address(1);

        // Set an options contract that will be the only valid caller of the contract
        newCollectionWars.setOptionsContract(validCaller);

        // Confirm the event fired by the call
        vm.expectEmit(true, true, false, true, address(newCollectionWars));
        emit NftVoteCast(validCaller, war, collections[0], votesA, votesA);

        // Make a call that will cast `votesA` against `collections[0]`
        vm.prank(validCaller);
        newCollectionWars.optionVote(validCaller, war, collections[0], votesA);

        // Confirm the event fired by the call
        vm.expectEmit(true, true, false, true, address(newCollectionWars));
        emit NftVoteCast(validCaller, war, collections[0], uint(votesA) + uint(votesB), uint(votesA) + uint(votesB));

        // Make a second call that will cast `votesB` against `collections[0]`
        vm.prank(validCaller);
        newCollectionWars.optionVote(validCaller, war, collections[0], votesB);

        // Confirm the event fired by the call
        vm.expectEmit(true, true, false, true, address(newCollectionWars));
        emit NftVoteCast(validCaller, war, collections[1], votesC, votesC);

        // Make a second call that will cast `votesB` against `collections[0]`
        vm.prank(validCaller);
        newCollectionWars.optionVote(validCaller, war, collections[1], votesC);

        // Confirm the votes that are as expected, with just NFT votes
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[0])), uint(votesA) + uint(votesB));
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[0])), uint(votesA) + uint(votesB));
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[1])), votesC);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[1])), votesC);

        // Make a normal vote, and confirm that the tallies are correct
        vm.prank(alice);
        newCollectionWars.vote(collections[0]);

        vm.prank(bob);
        newCollectionWars.vote(collections[1]);

        // Confirm the votes that are as expected, with NFT votes _and_ base votes
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[0])), uint(votesA) + uint(votesB) + 100 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[0])), uint(votesA) + uint(votesB));
        assertEq(newCollectionWars.collectionVotes(_warCollection(war, collections[1])), uint(votesC) + 50 ether);
        assertEq(newCollectionWars.collectionNftVotes(_warCollection(war, collections[1])), votesC);
    }

    function test_CannotVoteWithOptionWithoutPermissions(address invalidCaller) external defaultNewCollectionWar {
        // Set our valid caller address
        address validCaller = address(1);

        // Set our only valid caller address
        vm.assume(invalidCaller != validCaller);

        // Set an options contract that will be the only valid caller of the contract
        newCollectionWars.setOptionsContract(validCaller);

        // Attempt to make a valid call, but as an invalid caller
        vm.prank(invalidCaller);
        vm.expectRevert('Invalid caller');
        newCollectionWars.optionVote(validCaller, war, collections[0], 10 ether);
    }

    function test_CannotVoteWithOptionForInvalidWar() external defaultNewCollectionWar {
        // Set our valid caller address
        address validCaller = address(1);

        // Set an options contract that will be the only valid caller of the contract
        newCollectionWars.setOptionsContract(validCaller);

        // Attempt to make a valid call, but as an invalid caller
        vm.prank(validCaller);
        vm.expectRevert('Invalid war');
        newCollectionWars.optionVote(validCaller, 2, collections[0], 10 ether);
    }

    function _warUser(uint warIndex, address user) internal pure returns (bytes32) {
        return keccak256(abi.encode(warIndex, user));
    }

    function _warCollection(uint warIndex, address collection) internal pure returns (bytes32) {
        return keccak256(abi.encode(warIndex, collection));
    }

    function _createFloorWarsParameters(uint indexes) internal pure returns (address[] memory collections_, bool[] memory isErc1155_, uint[] memory floorPrices_) {
        // Set up a collections array
        collections_ = new address[](indexes);
        isErc1155_ = new bool[](indexes);
        floorPrices_ = new uint[](indexes);

        for (uint i = 1; i <= indexes; ++i) {
            collections_[i - 1] = address(uint160(i));
            isErc1155_[i - 1] = (i % 3 == 0);
            floorPrices_[i - 1] = i * 1 ether;
        }
    }

    /**
     * Some tests don't want the existing war running. This modifier will end the war
     * before the next test starts.
     */
    modifier defaultNewCollectionWar {
        // Set up a collections array
        collections = new address[](5);
        collections[0] = address(1);
        collections[1] = address(mock721);
        collections[2] = address(mock1155);
        collections[3] = address(4);
        collections[4] = address(5);

        isErc1155 = new bool[](5);
        isErc1155[0] = false;
        isErc1155[1] = false;
        isErc1155[2] = true;
        isErc1155[3] = false;
        isErc1155[4] = false;

        floorPrices = new uint[](5);
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

        _;
    }

    /**
     * Allows our contract to receive dust ETH back from sweeps.
     */
    receive() external payable {}
}
