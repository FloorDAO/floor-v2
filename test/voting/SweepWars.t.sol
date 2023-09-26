// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SignedMath} from '@openzeppelin/contracts/utils/math/SignedMath.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
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

import {NftStakingMock} from '../mocks/NftStaking.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract SweepWarsTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    // Store our max epoch index
    uint internal constant MAX_EPOCH_INDEX = 3;

    // Contract references to be deployed
    CollectionRegistry collectionRegistry;
    EpochManager epochManager;
    FLOOR floor;
    SweepWars sweepWars;
    Treasury treasury;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;
    VeFloorStaking veFloor;

    // A set of collections to be referenced during testing
    address approvedCollection1 = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address approvedCollection2 = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address approvedCollection3 = 0x524cAB2ec69124574082676e6F654a18df49A048;
    address unapprovedCollection1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address unapprovedCollection2 = 0xd68c4149Ec6fC585124E8827a2b102b68712543c;
    address floorTokenCollection;

    // Our approved strategy
    address approvedStrategy;

    // Store some test user wallets
    address alice;
    address bob;
    address carol;

    // Store vote power from setUp
    mapping(address => uint) votePower;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Create our {CollectionRegistry}
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Define our strategy implementations
        approvedStrategy = address(new NFTXInventoryStakingStrategy());

        // Create our {StrategyRegistry} and approve the strategy implementation
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        strategyRegistry.approveStrategy(approvedStrategy, true);

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

        // Set up our FLOOR token as the actual collection
        floorTokenCollection = address(floor);

        // Create our {EpochManager} and assign the contract to our test contracts
        epochManager = new EpochManager();
        veFloor.setEpochManager(address(epochManager));

        // Set our war contracts against our staking contract
        veFloor.setVotingContracts(address(0), address(sweepWars));

        // Approve our VeFloor staking contract to revoke war votes
        authorityRegistry.grantRole(authorityControl.VOTE_MANAGER(), address(veFloor));

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection1);
        collectionRegistry.approveCollection(approvedCollection2);
        collectionRegistry.approveCollection(approvedCollection3);
        collectionRegistry.approveCollection(floorTokenCollection);

        // Set up shorthand for our test users
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Label our approved collections for easier traces
        vm.label(floorTokenCollection, 'floorTokenCollection');
        vm.label(approvedCollection1, 'approvedCollection1');
        vm.label(approvedCollection2, 'approvedCollection2');
        vm.label(approvedCollection3, 'approvedCollection3');
        vm.label(unapprovedCollection1, 'unapprovedCollection1');
        vm.label(unapprovedCollection2, 'unapprovedCollection2');
        vm.label(approvedStrategy, 'approvedStrategy');
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

        votePower[alice] = veFloor.balanceOf(alice);
        votePower[bob] = veFloor.balanceOf(bob);
    }

    function test_canGetZeroVotingPower(address unknown) public {
        // Ensure our Alice test user is not included in this test
        // as she may have been allocated veFloor tokens.
        vm.assume(unknown != alice && unknown != bob);

        // All other addresses should have 0 balance
        assertEq(sweepWars.userVotingPower(unknown), 0);
    }

    function test_canGetVotingPowerWithVeFloorBalance() public {
        assertEq(sweepWars.userVotingPower(alice), votePower[alice]);
    }

    function test_canGetVotesAvailableWithNoBalanceOrVotes(address unknown) public {
        // Ensure our Alice test user is not included in this test
        // as she may have been allocated veFloor tokens.
        vm.assume(unknown != alice && unknown != bob);

        // All other addresses should have 0 balance
        assertEq(sweepWars.userVotesAvailable(unknown), 0);
    }

    function test_canGetVotesAvailableWithVeBalanceAndZeroVotes() public {
        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice]);
    }

    function test_canGetVotesAvailableWithVeBalanceAndVotesCast(int voteAmount) public assumeVotesInRange(alice, voteAmount) {
        vm.assume(voteAmount != 0);

        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice]);

        vm.prank(alice);
        sweepWars.vote(approvedCollection1, voteAmount);

        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice] - SignedMath.abs(voteAmount));
    }

    function test_cannotVoteWithZeroBalance() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesAvailable.selector, 1 ether, 0));
        vm.prank(address(0));
        sweepWars.vote(approvedCollection1, 1 ether);

        assertEq(sweepWars.votes(approvedCollection1), 0);
    }

    function test_cannotVoteWithMoreTokensThanBalance() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesAvailable.selector, 101 ether, votePower[alice]));
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 101 ether);

        assertEq(sweepWars.votes(approvedCollection1), 0);
    }

    function test_cannotVoteWithMoreTokensThanUnvoted() public {
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 80 ether);

        assertEq(sweepWars.votes(approvedCollection1), 80 ether);

        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesAvailable.selector, 21 ether, votePower[alice] - 80 ether));

        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 21 ether);

        assertEq(sweepWars.votes(approvedCollection1), 80 ether);
    }

    function test_cannotVoteOnUnapprovedCollection() public {
        vm.expectRevert(abi.encodeWithSelector(CollectionNotApproved.selector, unapprovedCollection1));
        vm.prank(alice);
        sweepWars.vote(unapprovedCollection1, 1 ether);

        assertEq(sweepWars.votes(unapprovedCollection1), 0);
    }

    function test_cannotVoteWithZeroAmount() public {
        vm.expectRevert(CannotVoteWithZeroAmount.selector);
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 0);
    }

    function test_canVote(int votes) public assumeVotesInRange(alice, votes) {
        // Prevent voting with a zero amount
        vm.assume(votes != 0);

        uint initialVotePower = sweepWars.userVotingPower(alice);

        assertEq(sweepWars.userVotingPower(alice), initialVotePower);
        assertEq(sweepWars.userVotesAvailable(alice), initialVotePower);
        assertEq(sweepWars.votes(approvedCollection1), 0);

        vm.prank(alice);
        sweepWars.vote(approvedCollection1, votes);

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.userVotingPower(alice), initialVotePower);
        assertEq(sweepWars.userVotesAvailable(alice), initialVotePower - SignedMath.abs(votes));
        assertEq(sweepWars.votes(approvedCollection1), votes);
    }

    function test_canVoteOnFloorTokenAddress() public {
        vm.prank(alice);
        sweepWars.vote(floorTokenCollection, 1 ether);

        assertEq(sweepWars.votes(floorTokenCollection), 1 ether);
    }

    function test_canVoteMultipleTimesOnSameCollection() public {
        uint initialVotePower = sweepWars.userVotingPower(alice);

        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.vote(approvedCollection1, -5 ether);
        vm.stopPrank();

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.userVotingPower(alice), initialVotePower);
        assertEq(sweepWars.userVotesAvailable(alice), initialVotePower - 15 ether);
        assertEq(sweepWars.votes(approvedCollection1), 5 ether);
    }

    function test_canVoteOnMultipleApprovedCollections() public {
        uint initialVotePower = sweepWars.userVotingPower(alice);

        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.vote(approvedCollection2, -5 ether);
        sweepWars.vote(approvedCollection3, 15 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 10 ether);
        assertEq(sweepWars.votes(approvedCollection2), -5 ether);
        assertEq(sweepWars.votes(approvedCollection3), 15 ether);

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.userVotingPower(alice), initialVotePower);
        assertEq(sweepWars.userVotesAvailable(alice), initialVotePower - 30 ether);
    }

    function test_canRevokeVoteOnUnvotedCollection() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        vm.prank(alice);
        sweepWars.revokeVotes(collections);
    }

    function test_canRevokeWithNoCollections() public {
        address[] memory collections = new address[](0);

        vm.prank(alice);
        sweepWars.revokeVotes(collections);
    }

    function test_canFullyRevokeVotes() public {
        uint initialVotePower = sweepWars.userVotingPower(alice);

        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.revokeVotes(collections);
        vm.stopPrank();

        // Check the user's account data and other expected state changes
        assertEq(sweepWars.userVotingPower(alice), initialVotePower);
        assertEq(sweepWars.userVotesAvailable(alice), initialVotePower);
        assertEq(sweepWars.votes(approvedCollection1), 0);
    }

    function test_canRevokeVotesFromMultipleCollections() public {
        uint initialVotePower = sweepWars.userVotingPower(alice);

        vm.startPrank(alice);

        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.vote(approvedCollection2, 5 ether);
        sweepWars.vote(approvedCollection3, 15 ether);

        address[] memory collections = new address[](2);
        collections[0] = approvedCollection1;
        collections[1] = approvedCollection2;

        sweepWars.revokeVotes(collections);

        vm.stopPrank();

        // Check the user's account data and other expected state changes
        assertEq(sweepWars.userVotingPower(alice), initialVotePower);
        assertEq(sweepWars.userVotesAvailable(alice), initialVotePower - 15 ether);
        assertEq(sweepWars.votes(approvedCollection1), 0);
        assertEq(sweepWars.votes(approvedCollection2), 0);
        assertEq(sweepWars.votes(approvedCollection3), 15 ether);
    }

    function test_canRevokeAllUserVotesWithoutAnyVotes() public {
        sweepWars.revokeAllUserVotes(alice);
    }

    function test_canRevokeAllUserVotes() public {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection2, 2 ether);
        sweepWars.vote(approvedCollection3, -3 ether);
        sweepWars.vote(floorTokenCollection, 4 ether);
        vm.stopPrank();

        assertEq(sweepWars.userVotingPower(alice), votePower[alice]);
        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice] - 10 ether);

        sweepWars.revokeAllUserVotes(alice);

        assertEq(sweepWars.votes(approvedCollection1), 0);
        assertEq(sweepWars.votes(approvedCollection2), 0);
        assertEq(sweepWars.votes(approvedCollection3), 0);
        assertEq(sweepWars.votes(floorTokenCollection), 0);

        assertEq(sweepWars.userVotingPower(alice), votePower[alice]);
        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice]);
    }

    function test_cannotSetSampleSizeWithoutPermission() public {
        assertEq(sweepWars.sampleSize(), 5);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.VOTE_MANAGER()));
        vm.prank(alice);
        sweepWars.setSampleSize(10);

        assertEq(sweepWars.sampleSize(), 5);
    }

    function test_cannotSetSampleSizeToZero() public {
        assertEq(sweepWars.sampleSize(), 5);

        vm.expectRevert(SampleSizeCannotBeZero.selector);
        sweepWars.setSampleSize(0);

        assertEq(sweepWars.sampleSize(), 5);
    }

    function test_canSetSampleSize() public {
        assertEq(sweepWars.sampleSize(), 5);

        sweepWars.setSampleSize(10);

        assertEq(sweepWars.sampleSize(), 10);
    }

    function test_canTakeSnapshot() public {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether);
        sweepWars.vote(approvedCollection2, 10 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, 5 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection3, 2 ether);
        sweepWars.vote(floorTokenCollection, 10 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 2 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), 8 ether);
        assertEq(sweepWars.votes(floorTokenCollection), 15 ether);

        sweepWars.setSampleSize(3);

        // Create a vault for our collections
        _createCollectionVault(approvedCollection1, 'Vault 1');
        _createCollectionVault(approvedCollection2, 'Vault 2');
        _createCollectionVault(approvedCollection3, 'Vault 3');
        _createCollectionVault(approvedCollection3, 'Vault 4');

        (address[] memory collections, uint[] memory amounts) = sweepWars.snapshot(10000 ether);

        assertEq(collections.length, 3);
        assertEq(amounts.length, 3);

        assertEq(collections[0], floorTokenCollection);
        assertEq(collections[1], approvedCollection2);
        assertEq(collections[2], approvedCollection3);

        assertEq(amounts[0], 4545454545454545450000);
        assertEq(amounts[1], 3030303030303030300000);
        assertEq(amounts[2], 2424242424242424250000);

        assertEq(amounts[0] + amounts[1] + amounts[2], 10000 ether);
    }

    function test_CanImplementNftStakingBoost() external {
        // Set an arbritrary NFT Staking contract address that we will mock
        NftStakingMock nftStaking = new NftStakingMock();
        sweepWars.setNftStaking(address(nftStaking));

        // Cast votes
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        vm.prank(bob);
        sweepWars.vote(approvedCollection1, 5 ether);

        // Mock modifier calculation to return 1.00 and confirm multiplier has been applied
        vm.mockCall(
            address(nftStaking),
            abi.encodeWithSelector(NftStakingMock.collectionBoost.selector, approvedCollection1, int(15 ether)),
            abi.encode(int(15 ether))
        );
        assertEq(sweepWars.votes(approvedCollection1), 15 ether);

        // Mock modifier calculation to return 1.50 and confirm effect
        vm.mockCall(
            address(nftStaking),
            abi.encodeWithSelector(NftStakingMock.collectionBoost.selector, approvedCollection1, int(15 ether)),
            abi.encode(int(22.5 ether))
        );
        assertEq(sweepWars.votes(approvedCollection1), 22.5 ether);
    }

    function test_CanVoteAgainstCollection() external {
        // Make an initial "against" vote of 10 ether
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, -10 ether);

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.votes(approvedCollection1), -10 ether);

        // Make an additional "against" vote of 5 ether
        vm.prank(bob);
        sweepWars.vote(approvedCollection1, -5 ether);

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.votes(approvedCollection1), -15 ether);

        // Make a "for" vote with bob that will increase it by 10 ether
        vm.prank(bob);
        sweepWars.vote(approvedCollection1, 10 ether);

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.votes(approvedCollection1), -5 ether);

        // Check how many votes we will have at at specific epochs, which should be
        // the same as we no longer have any power burn.
        assertEq(sweepWars.votes(approvedCollection1), -5 ether);
        assertEq(sweepWars.votes(approvedCollection1), -5 ether);
        assertEq(sweepWars.votes(approvedCollection1), -5 ether);
    }

    function test_CanExcludeZeroOrNegativeCollectionVotesFromSnapshot() external {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 2 ether);
        sweepWars.vote(approvedCollection2, 10 ether);
        sweepWars.vote(approvedCollection3, 6 ether);
        sweepWars.vote(floorTokenCollection, 5 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection3, -4 ether);
        sweepWars.vote(floorTokenCollection, -10 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 3 ether);
        assertEq(sweepWars.votes(approvedCollection2), 10 ether);
        assertEq(sweepWars.votes(approvedCollection3), 2 ether);
        assertEq(sweepWars.votes(floorTokenCollection), -5 ether);

        sweepWars.setSampleSize(2);

        // Create a vault for our collections
        _createCollectionVault(approvedCollection1, 'Vault 1');
        _createCollectionVault(approvedCollection2, 'Vault 2');
        _createCollectionVault(approvedCollection3, 'Vault 3');
        _createCollectionVault(approvedCollection3, 'Vault 4');

        (address[] memory collections, uint[] memory amounts) = sweepWars.snapshot(10000 ether);

        assertEq(collections.length, 2);
        assertEq(amounts.length, 2);

        assertEq(collections[0], approvedCollection2);
        assertEq(collections[1], approvedCollection1);

        assertEq(amounts[0], 7692307692307692300000);
        assertEq(amounts[1], 2307692307692307700000);

        assertEq(amounts[0] + amounts[1], 10000 ether);

        // Now add a higher snapshot sample size to ensure that negative votes are negated
        sweepWars.setSampleSize(5);

        // Retake our snapshot and confirm that it does not include negative values
        (collections, amounts) = sweepWars.snapshot(10000 ether);

        assertEq(collections.length, 3);
        assertEq(amounts.length, 3);

        assertEq(collections[0], approvedCollection2);
        assertEq(collections[1], approvedCollection1);
        assertEq(collections[2], approvedCollection3);

        assertAlmostEqual(amounts[0], 6666 ether, 1e2);
        assertEq(amounts[1], 2000 ether);
        assertAlmostEqual(amounts[2], 1333 ether, 1e2);

        assertEq(amounts[0] + amounts[1] + amounts[2], 10000 ether);
    }

    /**
     * The sweep wars contract records a user's voting power based on the ratio at the beginning
     * of their vote. When votes are removed the contract calculates the user's current voting
     * power based on their current locking ratio and then either removes those votes if the vote
     * is for for a collection or adds them if the vote is against a collection.
     *
     * The consequence of this is if a user can either increase or reduce their voting power after
     * voting some remainder will be left when they withdraw at the end because the voting power
     * ratio at the end of the locking period is not equal to what it was at the beginning. This
     * allows vote duplication via the following steps:
     *
     *   1) Deposit at the lowest possible lock length (2 weeks)
     *   2) Vote in the opposite of the preferred direction (with 1/12 ie about 8.6% of total votes)
     *   3) Extend lock by depositing again to the longest lock length (24 weeks)
     *   4) Wait for lock to end and withdraw causing the correction to overshoot because the user's
     *      current voting power is 100% of what was deposited (by aprox 91.4% with current constants)
     *   5) Deposit and vote again and you will have added 191% of your voting power to your preferred
     *      collection.
     *
     * Severity Estimate: Critical [Impact: High, Likelihood: High]
     * Remediation Recommendation: Store real user votes not their total amount of floor voted.
     */
    function test_CannotDuplicateVote() external {
        // Give Carol some FLOOR tokens to use
        floor.mint(carol, 100 ether);

        vm.startPrank(carol);

        // Approve our FLOOR tokens for use
        floor.approve(address(veFloor), 100 ether);

        assertEq(sweepWars.userVotingPower(carol), 0);
        assertEq(sweepWars.userVotesAvailable(carol), 0);
        assertEq(sweepWars.votes(floorTokenCollection), 0);

        // 1) Deposit at the lowest possible lock length (2 weeks)
        veFloor.deposit(10 ether, 0);

        assertEq(sweepWars.userVotingPower(carol), uint(10 ether) / uint(6));
        assertEq(sweepWars.userVotesAvailable(carol), uint(10 ether) / uint(6));
        assertEq(sweepWars.votes(floorTokenCollection), 0);

        // 2) Vote in the opposite of the preferred direction (with 1/6 ie about 16.67% of total votes)
        sweepWars.vote(floorTokenCollection, -1 ether);

        assertEq(sweepWars.userVotingPower(carol), uint(10 ether) / uint(6));
        assertEq(sweepWars.userVotesAvailable(carol), (uint(10 ether) / uint(6)) - 1 ether);
        assertEq(sweepWars.votes(floorTokenCollection), int(-1 ether));

        // 3) Extend lock by depositing again to the longest lock length (12 epochs)
        veFloor.deposit(10 ether, MAX_EPOCH_INDEX);

        assertEq(sweepWars.userVotingPower(carol), 20 ether);
        assertEq(sweepWars.userVotesAvailable(carol), 19 ether);
        assertEq(sweepWars.votes(floorTokenCollection), int(-1 ether));

        vm.stopPrank();

        // 4) Wait for lock to end and withdraw causing the correction to overshoot because the user's
        // current voting power is 100% of what was deposited (by aprox 91.4% with current constants)
        setCurrentEpoch(address(epochManager), 12);

        vm.startPrank(carol);

        veFloor.withdraw();

        assertEq(sweepWars.userVotingPower(carol), 0);
        assertEq(sweepWars.userVotesAvailable(carol), 0);
        assertEq(sweepWars.votes(floorTokenCollection), 0);

        // 5) Deposit and vote again and you will have added 191% of your voting power to your
        // preferred collection.
        veFloor.deposit(10 ether, MAX_EPOCH_INDEX);
        sweepWars.vote(floorTokenCollection, 10 ether);

        assertEq(sweepWars.userVotingPower(carol), 10 ether);
        assertEq(sweepWars.userVotesAvailable(carol), 0);
        assertEq(sweepWars.votes(floorTokenCollection), 10 ether);

        vm.stopPrank();
    }

    /**
     * Ensures that the used library returns the correct abs() responses.
     */
    function test_CanGetCorrectAbsResults() external {
        // Ensure our `type(int).min` is handled
        assertEq(type(int).min, -57896044618658097711785492504343953926634992332820282019728792003956564819968);
        assertEq(SignedMath.abs(type(int).min), 57896044618658097711785492504343953926634992332820282019728792003956564819968);

        // Confirm 0 = 0
        assertEq(SignedMath.abs(int(0)), 0);

        // Confirm our max value is handled
        assertEq(type(int).max, 57896044618658097711785492504343953926634992332820282019728792003956564819967);
        assertEq(SignedMath.abs(type(int).max), 57896044618658097711785492504343953926634992332820282019728792003956564819967);
    }

    function _createCollectionVault(address collection, string memory vaultName) internal returns (address vaultAddr_) {
        // Approvals aren't needed and may throw issues with our mocked setups
        vm.mockCall(collection, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

        // Create the vault via the factory
        (, vaultAddr_) = strategyFactory.deployStrategy(bytes32(bytes(vaultName)), approvedStrategy, _strategyInitBytes(), collection);

        // Label the vault for debugging help
        vm.label(vaultAddr_, vaultName);
    }

    /**
     * Sets a correct vote range assumption for fuzzing.
     */
    modifier assumeVotesInRange(address user, int fuzzVotes) {
        if (fuzzVotes < 0) {
            vm.assume(fuzzVotes >= -int(sweepWars.userVotingPower(user)));
        } else {
            vm.assume(fuzzVotes <= int(sweepWars.userVotingPower(user)));
        }

        _;
    }

}
