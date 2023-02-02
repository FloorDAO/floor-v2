// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../../src/contracts/collections/CollectionRegistry.sol';
import {VeFloorStaking} from '../../src/contracts/staking/VeFloorStaking.sol';
import '../../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import '../../src/contracts/strategies/StrategyRegistry.sol';
import '../../src/contracts/tokens/Floor.sol';
import '../../src/contracts/vaults/Vault.sol';
import '../../src/contracts/vaults/VaultFactory.sol';
import '../../src/contracts/voting/GaugeWeightVote.sol';

import '../utilities/Environments.sol';

contract GaugeWeightVoteTest is FloorTest {
    // Contract references to be deployed
    CollectionRegistry collectionRegistry;
    FLOOR floor;
    GaugeWeightVote gaugeWeightVote;
    StrategyRegistry strategyRegistry;
    Vault vaultImplementation;
    VaultFactory vaultFactory;
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
    mapping (address => uint) votePower;

    constructor() {
        // Create our {StrategyRegistry}
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Define our strategy implementations
        approvedStrategy = address(new NFTXInventoryStakingStrategy(bytes32('Approved Strategy')));

        // Approve our test strategy implementation
        strategyRegistry.approveStrategy(approvedStrategy);

        // Create our {CollectionRegistry}
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Approve our test collection
        collectionRegistry.approveCollection(approvedCollection1);
        collectionRegistry.approveCollection(approvedCollection2);
        collectionRegistry.approveCollection(approvedCollection3);

        // Deploy our vault implementation
        vaultImplementation = new Vault();

        // Deploy our vault implementation
        address vaultXTokenImplementation = address(new VaultXToken());

        // Deploy our FLOOR token
        floor = new FLOOR(address(authorityRegistry));

        // Create our {VaultFactory}
        vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            address(vaultImplementation),
            vaultXTokenImplementation,
            address(floor)
        );

        // Set up our veFloor token
        veFloor = new VeFloorStaking(floor, STAKING_EXP_BASE, address(2));

        // Now that we have all our dependencies, we can deploy our
        // {GaugeWeightVote} contract.
        gaugeWeightVote = new GaugeWeightVote(
            address(collectionRegistry),
            address(vaultFactory),
            address(veFloor),
            address(authorityRegistry)
        );

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
        veFloor.deposit(100 ether, 2 * 365 days);
        vm.stopPrank();

        vm.startPrank(bob);
        floor.approve(address(veFloor), 100 ether);
        veFloor.deposit(100 ether, 2 * 365 days);
        vm.stopPrank();

        votePower[alice] = veFloor.balanceOf(alice);
        votePower[bob] = veFloor.balanceOf(bob);
    }

    function test_canGetZeroVotingPower(address unknown) public {
        // Ensure our Alice test user is not included in this test
        // as she may have been allocated veFloor tokens.
        vm.assume(unknown != alice && unknown != bob);

        // All other addresses should have 0 balance
        assertEq(gaugeWeightVote.userVotingPower(unknown), 0);
    }

    function test_canGetVotingPowerWithVeFloorBalance() public {
        assertEq(gaugeWeightVote.userVotingPower(alice), votePower[alice]);
    }

    function test_canGetVotesAvailableWithNoBalanceOrVotes(address unknown) public {
        // Ensure our Alice test user is not included in this test
        // as she may have been allocated veFloor tokens.
        vm.assume(unknown != alice && unknown != bob);

        // All other addresses should have 0 balance
        assertEq(gaugeWeightVote.userVotesAvailable(unknown), 0);
    }

    function test_canGetVotesAvailableWithVeBalanceAndZeroVotes() public {
        assertEq(gaugeWeightVote.userVotesAvailable(alice), votePower[alice]);
    }

    function test_canGetVotesAvailableWithVeBalanceAndVotesCast(uint voteAmount) public {
        vm.assume(voteAmount > 0);
        vm.assume(voteAmount <= veFloor.balanceOf(alice));

        assertEq(gaugeWeightVote.userVotesAvailable(alice), votePower[alice]);

        vm.prank(alice);
        gaugeWeightVote.vote(approvedCollection1, voteAmount);

        assertEq(gaugeWeightVote.userVotesAvailable(alice), votePower[alice] - voteAmount);
    }

    function test_cannotVoteWithZeroBalance() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesAvailable.selector, 1 ether, 0));
        vm.prank(address(0));
        gaugeWeightVote.vote(approvedCollection1, 1 ether);

        assertEq(gaugeWeightVote.votes(approvedCollection1), 0);
    }

    function test_cannotVoteWithMoreTokensThanBalance() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesAvailable.selector, 101 ether, votePower[alice]));
        vm.prank(alice);
        gaugeWeightVote.vote(approvedCollection1, 101 ether);

        assertEq(gaugeWeightVote.votes(approvedCollection1), 0);
    }

    function test_cannotVoteWithMoreTokensThanUnvoted() public {
        vm.prank(alice);
        gaugeWeightVote.vote(approvedCollection1, 80 ether);

        assertEq(gaugeWeightVote.votes(approvedCollection1), 80 ether);

        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesAvailable.selector, 21 ether, votePower[alice] - 80 ether));
        vm.prank(alice);
        gaugeWeightVote.vote(approvedCollection1, 21 ether);

        assertEq(gaugeWeightVote.votes(approvedCollection1), 80 ether);
    }

    function test_cannotVoteOnUnapprovedCollection() public {
        vm.expectRevert(abi.encodeWithSelector(CollectionNotApproved.selector, unapprovedCollection1));
        vm.prank(alice);
        gaugeWeightVote.vote(unapprovedCollection1, 1 ether);

        assertEq(gaugeWeightVote.votes(unapprovedCollection1), 0);
    }

    function test_cannotVoteWithZeroAmount() public {
        vm.expectRevert(CannotVoteWithZeroAmount.selector);
        vm.prank(alice);
        gaugeWeightVote.vote(approvedCollection1, 0);
    }

    function test_canVote() public {
        vm.prank(alice);
        gaugeWeightVote.vote(approvedCollection1, 1 ether);

        assertEq(gaugeWeightVote.votes(approvedCollection1), 1 ether);
    }

    function test_canVoteOnFloorTokenAddress() public {
        vm.prank(alice);
        gaugeWeightVote.vote(floorTokenCollection, 1 ether);

        assertEq(gaugeWeightVote.votes(floorTokenCollection), 1 ether);
    }

    function test_canVoteMultipleTimesOnSameCollection() public {
        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 10 ether);
        gaugeWeightVote.vote(approvedCollection1, 5 ether);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 15 ether);
    }

    function test_canVoteOnMultipleApprovedCollections() public {
        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 10 ether);
        gaugeWeightVote.vote(approvedCollection2, 5 ether);
        gaugeWeightVote.vote(approvedCollection3, 15 ether);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 10 ether);
        assertEq(gaugeWeightVote.votes(approvedCollection2), 5 ether);
        assertEq(gaugeWeightVote.votes(approvedCollection3), 15 ether);
    }

    function test_cannotRevokeVoteOnUnvotedCollection() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        uint[] memory amounts = new uint[](1);
        amounts[0] = 10 ether;

        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesToRevoke.selector, 10 ether, 0));
        vm.prank(alice);
        gaugeWeightVote.revokeVotes(collections, amounts);
    }

    function test_cannotRevokeWithUnbalancedArrayParameters() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        uint[] memory amounts = new uint[](0);

        vm.expectRevert(InvalidCollectionsAndAmounts.selector);
        vm.prank(alice);
        gaugeWeightVote.revokeVotes(collections, amounts);

        amounts = new uint[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        vm.expectRevert(InvalidCollectionsAndAmounts.selector);
        vm.prank(alice);
        gaugeWeightVote.revokeVotes(collections, amounts);
    }

    function test_cannotRevokeWithNoCollections() public {
        address[] memory collections = new address[](0);
        uint[] memory amounts = new uint[](0);

        vm.expectRevert(InvalidCollectionsAndAmounts.selector);
        vm.prank(alice);
        gaugeWeightVote.revokeVotes(collections, amounts);
    }

    function test_cannotRevokeVotesWithNoVotesPlaced() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        uint[] memory amounts = new uint[](1);
        amounts[0] = 5 ether;

        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesToRevoke.selector, 5 ether, 0));
        vm.prank(alice);
        gaugeWeightVote.revokeVotes(collections, amounts);
    }

    function test_canPartiallyRevokeVotes() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        uint[] memory amounts = new uint[](1);
        amounts[0] = 2 ether;

        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 10 ether);
        gaugeWeightVote.revokeVotes(collections, amounts);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 8 ether);
    }

    function test_canFullyRevokeVotes() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        uint[] memory amounts = new uint[](1);
        amounts[0] = 10 ether;

        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 10 ether);
        gaugeWeightVote.revokeVotes(collections, amounts);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 0);
    }

    function test_canRevokeVotesFromMultipleCollections() public {
        address[] memory collections = new address[](2);
        collections[0] = approvedCollection1;
        collections[1] = approvedCollection2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 2 ether;
        amounts[1] = 5 ether;

        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 10 ether);
        gaugeWeightVote.vote(approvedCollection2, 5 ether);
        gaugeWeightVote.revokeVotes(collections, amounts);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 8 ether);
        assertEq(gaugeWeightVote.votes(approvedCollection2), 0);
    }

    function test_cannotRevokeMoreThanVotes() public {
        address[] memory collections = new address[](1);
        collections[0] = approvedCollection1;

        uint[] memory amounts = new uint[](1);
        amounts[0] = 20 ether;

        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 10 ether);

        vm.expectRevert(abi.encodeWithSelector(InsufficientVotesToRevoke.selector, 20 ether, 10 ether));
        gaugeWeightVote.revokeVotes(collections, amounts);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 10 ether);
    }

    function test_canRevokeAllUserVotesWithoutAnyVotes() public {
        gaugeWeightVote.revokeAllUserVotes(alice);
    }

    function test_canRevokeAllUserVotes() public {
        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 1 ether);
        gaugeWeightVote.vote(approvedCollection2, 2 ether);
        gaugeWeightVote.vote(approvedCollection3, 3 ether);
        gaugeWeightVote.vote(floorTokenCollection, 4 ether);
        vm.stopPrank();

        assertEq(gaugeWeightVote.userVotingPower(alice), votePower[alice]);
        assertEq(gaugeWeightVote.userVotesAvailable(alice), votePower[alice] - 10 ether);

        gaugeWeightVote.revokeAllUserVotes(alice);

        assertEq(gaugeWeightVote.votes(approvedCollection1), 0);
        assertEq(gaugeWeightVote.votes(approvedCollection2), 0);
        assertEq(gaugeWeightVote.votes(approvedCollection3), 0);
        assertEq(gaugeWeightVote.votes(floorTokenCollection), 0);

        assertEq(gaugeWeightVote.userVotingPower(alice), votePower[alice]);
        assertEq(gaugeWeightVote.userVotesAvailable(alice), votePower[alice]);
    }

    function test_cannotSetSampleSizeWithoutPermission() public {
        assertEq(gaugeWeightVote.sampleSize(), 5);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.VOTE_MANAGER()));
        vm.prank(alice);
        gaugeWeightVote.setSampleSize(10);

        assertEq(gaugeWeightVote.sampleSize(), 5);
    }

    function test_cannotSetSampleSizeToZero() public {
        assertEq(gaugeWeightVote.sampleSize(), 5);

        vm.expectRevert(SampleSizeCannotBeZero.selector);
        gaugeWeightVote.setSampleSize(0);

        assertEq(gaugeWeightVote.sampleSize(), 5);
    }

    function test_canSetSampleSize() public {
        assertEq(gaugeWeightVote.sampleSize(), 5);

        gaugeWeightVote.setSampleSize(10);

        assertEq(gaugeWeightVote.sampleSize(), 10);
    }

    function test_canTakeSnapshot() public {
        vm.startPrank(alice);
        gaugeWeightVote.vote(approvedCollection1, 2 ether);
        gaugeWeightVote.vote(approvedCollection2, 10 ether);
        gaugeWeightVote.vote(approvedCollection3, 6 ether);
        gaugeWeightVote.vote(floorTokenCollection, 5 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        gaugeWeightVote.vote(approvedCollection3, 2 ether);
        gaugeWeightVote.vote(floorTokenCollection, 10 ether);
        vm.stopPrank();

        assertEq(gaugeWeightVote.votes(approvedCollection1), 2 ether);
        assertEq(gaugeWeightVote.votes(approvedCollection2), 10 ether);
        assertEq(gaugeWeightVote.votes(approvedCollection3), 8 ether);
        assertEq(gaugeWeightVote.votes(floorTokenCollection), 15 ether);

        gaugeWeightVote.setSampleSize(3);

        // Approvals aren't needed and may throw issues with our mocked setups
        vm.mockCall(
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

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

        // Send ETH to GWV to distribute
        floor.mint(address(gaugeWeightVote), 10000 ether);

        (address[] memory collections) = gaugeWeightVote.snapshot(10000 ether);

        assertEq(collections.length, 3);

        assertEq(collections[0], floorTokenCollection);
        assertEq(collections[1], approvedCollection2);
        assertEq(collections[2], approvedCollection3);
    }

    /**
     * ...
     */
    function _createCollectionVault(address collection, string memory vaultName) internal returns (address vaultAddr_) {
        // Approvals aren't needed and may throw issues with our mocked setups
        vm.mockCall(collection, abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));

        // Create the vault via the factory
        (, vaultAddr_) = vaultFactory.createVault(vaultName, approvedStrategy, _strategyInitBytes(), collection);

        // Label the vault for debugging help
        vm.label(vaultAddr_, vaultName);

        // Mint an xToken so that we avoid zero totalSupply errors
        vm.startPrank(vaultAddr_);
        VaultXToken(IVault(vaultAddr_).xToken()).mint(address(this), 1);
        vm.stopPrank();
    }

    /**
     * ...
     */
    function _strategyInitBytes() internal pure returns (bytes memory) {
        return abi.encode(
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _underlyingToken
            0x08765C76C758Da951DC73D3a8863B34752Dd76FB, // _yieldToken
            0x3E135c3E981fAe3383A5aE0d323860a34CfAB893  // _inventoryStaking
        );
    }

    function _mockVaultStrategyRewardsGenerated(address vault, uint amount) internal {
        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(IVault.lastEpochRewards.selector),
            abi.encode(amount)
        );
    }
}
