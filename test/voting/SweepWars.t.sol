// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {CannotVoteWithZeroAmount, CollectionNotApproved, SweepWars, InsufficientVotesAvailable, SampleSizeCannotBeZero} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract SweepWarsTest is FloorTest {
    // Contract references to be deployed
    CollectionRegistry collectionRegistry;
    EpochManager epochManager;
    FLOOR floor;
    SweepWars sweepWars;
    Treasury treasury;
    StrategyFactory strategyFactory;
    VeFloorStaking veFloor;

    // A set of collections to be referenced during testing
    address approvedCollection1 = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address approvedCollection2 = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address approvedCollection3 = 0x524cAB2ec69124574082676e6F654a18df49A048;
    address unapprovedCollection1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address unapprovedCollection2 = 0xd68c4149Ec6fC585124E8827a2b102b68712543c;

    // Constant for floor token collection vote
    address floorTokenCollection = address(1);

    // Strat
    address approvedStrategy;

    // Store some test user wallets
    address alice;
    address bob;

    // Store vote power from setUp
    mapping(address => uint) votePower;

    constructor() {
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
            address(floor)
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

        // Define our strategy implementations
        approvedStrategy = address(new NFTXInventoryStakingStrategy());

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection1, SUFFICIENT_LIQUIDITY_COLLECTION);
        collectionRegistry.approveCollection(approvedCollection2, SUFFICIENT_LIQUIDITY_COLLECTION);
        collectionRegistry.approveCollection(approvedCollection3, SUFFICIENT_LIQUIDITY_COLLECTION);
        collectionRegistry.approveCollection(floorTokenCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Set up shorthand for our test users
        (alice, bob) = (users[0], users[1]);

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
        veFloor.deposit(100 ether, 6);
        vm.stopPrank();

        vm.startPrank(bob);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 6);
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

    function test_canGetVotesAvailableWithVeBalanceAndVotesCast(uint voteAmount) public {
        vm.assume(voteAmount > 0);
        vm.assume(voteAmount <= veFloor.balanceOf(alice));

        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice]);

        vm.prank(alice);
        sweepWars.vote(approvedCollection1, voteAmount);

        assertEq(sweepWars.userVotesAvailable(alice), votePower[alice] - voteAmount);
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

    function test_canVote() public {
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);

        // Check how many votes we will have at current epoch when vote was cast
        assertEq(sweepWars.votes(approvedCollection1), 10 ether);

        // Check how many votes we will have at a specific epoch (half way)
        assertAlmostEqual(sweepWars.votes(approvedCollection1, 52), 5 ether, 1e2);
    }

    function test_canVoteOnFloorTokenAddress() public {
        vm.prank(alice);
        sweepWars.vote(floorTokenCollection, 1 ether);

        assertEq(sweepWars.votes(floorTokenCollection), 1 ether);
    }

    function test_canVoteMultipleTimesOnSameCollection() public {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.vote(approvedCollection1, 5 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 15 ether);
    }

    function test_canVoteOnMultipleApprovedCollections() public {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.vote(approvedCollection2, 5 ether);
        sweepWars.vote(approvedCollection3, 15 ether);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 10 ether);
        assertEq(sweepWars.votes(approvedCollection2), 5 ether);
        assertEq(sweepWars.votes(approvedCollection3), 15 ether);
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
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.revokeVotes(collections);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 0);
    }

    function test_canRevokeVotesFromMultipleCollections() public {
        address[] memory collections = new address[](2);
        collections[0] = approvedCollection1;
        collections[1] = approvedCollection2;

        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        sweepWars.vote(approvedCollection2, 5 ether);
        sweepWars.revokeVotes(collections);
        vm.stopPrank();

        assertEq(sweepWars.votes(approvedCollection1), 0);
        assertEq(sweepWars.votes(approvedCollection2), 0);
    }

    function test_canRevokeAllUserVotesWithoutAnyVotes() public {
        sweepWars.revokeAllUserVotes(alice);
    }

    function test_canRevokeAllUserVotes() public {
        vm.startPrank(alice);
        sweepWars.vote(approvedCollection1, 1 ether);
        sweepWars.vote(approvedCollection2, 2 ether);
        sweepWars.vote(approvedCollection3, 3 ether);
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
        address vault1 = _createCollectionVault(approvedCollection1, 'Vault 1');
        address vault2 = _createCollectionVault(approvedCollection2, 'Vault 2');
        address vault3 = _createCollectionVault(approvedCollection3, 'Vault 3');
        address vault4 = _createCollectionVault(approvedCollection3, 'Vault 4');

        vm.label(vault1, 'vault1');
        vm.label(vault2, 'vault2');
        vm.label(vault3, 'vault3');
        vm.label(vault4, 'vault4');

        _mockVaultStrategyRewardsGenerated(vault1, 10 ether);
        _mockVaultStrategyRewardsGenerated(vault2, 20 ether);
        _mockVaultStrategyRewardsGenerated(vault3, 2 ether);
        _mockVaultStrategyRewardsGenerated(vault4, 6 ether);

        vm.startPrank(address(treasury));
        (address[] memory collections, uint[] memory amounts) = sweepWars.snapshot(10000 ether, 0);
        vm.stopPrank();

        assertEq(collections.length, 3);
        assertEq(amounts.length, 3);

        assertEq(collections[0], floorTokenCollection);
        assertEq(collections[1], approvedCollection2);
        assertEq(collections[2], approvedCollection3);

        assertEq(amounts[0], 4950 ether);
        assertEq(amounts[1], 3300 ether);
        assertEq(amounts[2], 1750 ether);

        assertEq(amounts[0] + amounts[1] + amounts[2], 10000 ether);
    }

    function test_CanImplementNftStakingBoost() external {
        // Set an arbritrary NFT Staking contract address that we will mock
        address nftStaking = address(2);
        sweepWars.setNftStaking(nftStaking);

        // Create a vault for our collections
        _createCollectionVault(approvedCollection2, 'Vault');

        // Cast votes
        vm.prank(alice);
        sweepWars.vote(approvedCollection1, 10 ether);
        vm.prank(bob);
        sweepWars.vote(approvedCollection1, 5 ether);

        // We need to calculate our selector manually as it uses an overloaded function
        bytes4 _selector = bytes4(keccak256('collectionBoost(address,uint256)'));

        // Mock modifier calculation to return 1.00 and confirm multiplier has been applied
        vm.mockCall(nftStaking, abi.encodeWithSelector(_selector, approvedCollection1, 0), abi.encode(1e9));
        assertEq(sweepWars.votes(approvedCollection1), 15 ether);

        // Mock modifier calculation to return 1.50 and confirm effect
        vm.mockCall(nftStaking, abi.encodeWithSelector(_selector, approvedCollection1, 0), abi.encode(1500000000));
        assertEq(sweepWars.votes(approvedCollection1), 22.5 ether);
    }

    /**
     * ...
     */
    function _createCollectionVault(address collection, string memory vaultName) internal returns (address vaultAddr_) {
        // Approvals aren't needed and may throw issues with our mocked setups
        vm.mockCall(collection, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

        // Create the vault via the factory
        (, vaultAddr_) = strategyFactory.deployStrategy(bytes32(bytes(vaultName)), approvedStrategy, _strategyInitBytes(), collection);

        // Label the vault for debugging help
        vm.label(vaultAddr_, vaultName);
    }

    function _mockVaultStrategyRewardsGenerated(address vault, uint amount) internal {
        // vm.mockCall(address(vault), abi.encodeWithSelector(IBaseStrategy.lastEpochRewards.selector), abi.encode(amount));
    }
}
