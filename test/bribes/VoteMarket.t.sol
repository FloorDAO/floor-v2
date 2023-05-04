// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {VoteMarket} from '@floor/bribes/VoteMarket.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract VoteMarketTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    // Store some user addresses to test with
    address alice;
    address feeCollector;
    address oracle;

    // Our vote market / bribe contract we are testing against
    VoteMarket voteMarket;

    // Store some approved collections to test against. This isn't important that they
    // are legit approved collections, but they just need to be constant addresses
    address approvedCollection = address(2);
    address approvedCollection2 = address(3);
    address approvedCollection3 = address(4);

    // Store some blacklists that are defined in the constructor to save time
    address[] emptyBlacklist;
    address[] aliceBlacklist;

    /// The WETH contract address used for price mappings
    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH public WETH;

    // Use a store for 2D merkle proof assignment in tests
    bytes32[][] merkleProofStore;

    // Define our claim registration arrays once that we can update per test
    address[] claimCollections;
    uint[] claimCollectionVotes;

    // Store our {EpochManager} so that we can control the current epoch
    EpochManager epochManager;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a small pool of test users
        (alice, feeCollector, oracle) = (users[0], users[1], users[2]);

        // ..
        CollectionRegistry collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Deploy our {VoteMarket} contract
        voteMarket = new VoteMarket(address(collectionRegistry), oracle, feeCollector);

        // Create our Epoch Manager
        epochManager = new EpochManager();

        // Set our Epoch Manager
        voteMarket.setEpochManager(address(epochManager));

        // Create an empty blacklist
        emptyBlacklist = new address[](0);

        // Create a blacklist that includes Alice
        aliceBlacklist = new address[](1);
        aliceBlacklist[0] = alice;

        // Map our WETH contract
        WETH = IWETH(WETH_ADDR);
    }

    function setUp() external {
        // Give our test account lots of ETH tokens to play with
        deal(address(this), 1000 ether);

        // Give our account sufficient WETH tokens to deposit into a bribe
        WETH.deposit{value: 500 ether}();

        // Approve our WETH to be used by our vote market contract
        WETH.approve(address(voteMarket), type(uint).max);

        // Delete anything stored in our claim data
        for (uint i; i < claimCollections.length;) {
            delete claimCollections[i];
            delete claimCollectionVotes[i];
            unchecked {
                ++i;
            }
        }
    }

    function test_CanCreateBribe() external {
        // Create a bribe, putting 25 WETH into the bribe of 5 epochs
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), 0, uint8(5), 0.05 ether, 25 ether, emptyBlacklist);

        (
            uint startEpoch,
            uint maxRewardPerVote,
            uint remainingRewards,
            uint totalRewardAmount,
            address collection,
            address rewardToken,
            address creator,
            uint8 numberOfEpochs
        ) = voteMarket.bribes(bribeId);

        assertEq(startEpoch, epochManager.currentEpoch());
        assertEq(maxRewardPerVote, 0.05 ether);
        assertEq(remainingRewards, 25 ether);
        assertEq(totalRewardAmount, 25 ether);
        assertEq(collection, approvedCollection);
        assertEq(rewardToken, address(WETH));
        assertEq(creator, address(this));
        assertEq(numberOfEpochs, uint8(5));
    }

    function test_CannotCreateBribeWithZeroAddressRewardToken() external {
        vm.expectRevert('Cannot be zero address');
        voteMarket.createBribe(approvedCollection, address(0), 0, uint8(5), 0.05 ether, 25 ether, emptyBlacklist);
    }

    function test_CannotCreateBribeUnderMinimumEpochs() external {
        vm.expectRevert('Invalid number of epochs');
        voteMarket.createBribe(approvedCollection, address(WETH), 0, uint8(0), 0.05 ether, 25 ether, emptyBlacklist);
    }

    function test_CannotCreateBribeInPast() external {
        epochManager.setCurrentEpoch(1);

        vm.expectRevert('Cannot start in past');
        voteMarket.createBribe(approvedCollection, address(WETH), 0, uint8(5), 0.05 ether, 25 ether, emptyBlacklist);
    }

    function test_CannotCreateBribeWithZeroTotalRewards() external {
        vm.expectRevert('Invalid amounts');
        voteMarket.createBribe(approvedCollection, address(WETH), 0, uint8(5), 0.05 ether, 0 ether, emptyBlacklist);
    }

    function test_CannotCreateBribeWithZeroMaxRewardPerVote() external {
        vm.expectRevert('Invalid amounts');
        voteMarket.createBribe(approvedCollection, address(WETH), 0, uint8(5), 0 ether, 25 ether, emptyBlacklist);
    }

    function test_CannotCreateBribeWithoutSufficientTokens() external {
        vm.expectRevert();
        voteMarket.createBribe(approvedCollection, address(WETH), 0, uint8(5), 0.05 ether, 100000 ether, emptyBlacklist);
    }

    function test_CanClaimAgainstSingleCollectionOnOneEpoch() external disableClaimWindow {
        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        bytes32 merkleRoot = hex'4a504f2fee32fc23741019fe5681ab66a64e33bf5dccd9f7ead6b34e66d7623e';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRoot, approvedCollection, 10 ether);

        // Set up our bribe
        voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProof[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProof[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        // Claim as Alice with a valid request
        _claimAllWithSingleValues(alice, 0, approvedCollection, 10 ether, merkleProof);

        // Ensure our recipient received the expected amount of WETH
        assertEq(WETH.balanceOf(alice), 490000000000000000);

        // Our fee collector should have received 2%
        assertEq(WETH.balanceOf(feeCollector), 10000000000000000);
    }

    function test_CanClaimAgainstSingleCollectionOverMultipleEpochs() external disableClaimWindow {
        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        // keccak256(abi.encode(alice, 1, approvedCollection, 5 ether))
        bytes32 merkleRootA = hex'4a504f2fee32fc23741019fe5681ab66a64e33bf5dccd9f7ead6b34e66d7623e';
        bytes32 merkleRootB = hex'fd79016930c4810cc92b41bf2558b32f4f15eda765071c35132598a571b94768';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRootA, approvedCollection, 10 ether);
        _registerClaimWithSingleVote(1, merkleRootB, approvedCollection, 5 ether);

        // Set up our bribe
        voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProofA = new bytes32[](3);
        merkleProofA[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProofA[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProofA[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        bytes32[] memory merkleProofB = new bytes32[](3);
        merkleProofB[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProofB[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProofB[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        uint[] memory epochs = new uint[](2);
        address[] memory collections = new address[](2);
        uint[] memory votes = new uint[](2);

        epochs[0] = 0;
        collections[0] = approvedCollection;
        votes[0] = 10 ether;
        merkleProofStore.push(merkleProofA);

        epochs[1] = 1;
        collections[1] = approvedCollection;
        votes[1] = 5 ether;
        merkleProofStore.push(merkleProofB);

        // Claim as Alice with a valid request
        voteMarket.claimAll(alice, epochs, collections, votes, merkleProofStore);

        // Ensure our recipient received the expected amount of WETH
        assertEq(WETH.balanceOf(alice), 735000000000000000);

        // Our fee collector should have received 2%
        assertEq(WETH.balanceOf(feeCollector), 15000000000000000);
    }

    function test_CanClaimAgainstMultipleCollections() external disableClaimWindow {
        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        // keccak256(abi.encode(alice, 0, approvedCollection2, 5 ether))
        // keccak256(abi.encode(alice, 1, approvedCollection2, 15 ether))

        // Epoch 0 merkle
        bytes32 merkleRootA = hex'69a573dd8dc3ed57ed4f0016e3a54d0b681d77e951a5c3f59b0bbdc017331566';

        // Epoch 1 merkle
        bytes32 merkleRootB = hex'c144e62f4bcbaf0abf9dd8945098737eba109e519ee1ba081b30eb1bc38fe6aa';

        // Register our merkle roots
        _registerClaimWithTwoVotes(0, merkleRootA, approvedCollection, approvedCollection2, 100 ether, 50 ether);
        _registerClaimWithSingleVote(1, merkleRootB, approvedCollection2, 50 ether);

        // Set up our bribe
        voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 250 ether, emptyBlacklist);
        voteMarket.createBribe(approvedCollection2, address(WETH), epochManager.currentEpoch(), uint8(2), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProofA = new bytes32[](3);
        merkleProofA[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a3';
        merkleProofA[1] = hex'9fc424ef398c7735da1cc92da686ceb8e5b894f988a9483c0c4afe81352cdaa2';
        merkleProofA[2] = hex'b348f8010e4885ec6b02e3e00c9fa93274d736c1ccf14e059b99bee1c2cd46dc';

        bytes32[] memory merkleProofB = new bytes32[](3);
        merkleProofB[0] = hex'dd8824e0480b87a7e97060f1c0a046b3ecd3aecdecd8962a21042cc95f5b3d7a';
        merkleProofB[1] = hex'19dac45e3184b65ba42391a9edad756b9d0dfe3b6c0b5ccbf32a52dbbc0e8900';
        merkleProofB[2] = hex'bbebc508ef8bd6c23d2494a8105f2cbac368e130046da09411fd275513b2f5d2';

        bytes32[] memory merkleProofC = new bytes32[](3);
        merkleProofC[0] = hex'51624faed8a83421daba1c3dd7681e2ce12efcc96b70775b9bdd54ddcc71ef8c';
        merkleProofC[1] = hex'051937ac4e89074334b9c2d09625b6806f6edc441b92bc48495f50f425355fda';
        merkleProofC[2] = hex'33eead0535ba6fa8b51bddf6b80f442d736b47878fbe6c2634eb6a9d29f81a74';

        uint[] memory epochs = new uint[](3);
        address[] memory collections = new address[](3);
        uint[] memory votes = new uint[](3);

        epochs[0] = 0;
        collections[0] = approvedCollection;
        votes[0] = 10 ether;
        merkleProofStore.push(merkleProofA);

        epochs[1] = 0;
        collections[1] = approvedCollection2;
        votes[1] = 5 ether;
        merkleProofStore.push(merkleProofB);

        epochs[2] = 1;
        collections[2] = approvedCollection2;
        votes[2] = 15 ether;
        merkleProofStore.push(merkleProofC);

        // Claim as Alice with a valid request
        voteMarket.claimAll(alice, epochs, collections, votes, merkleProofStore);

        // Ensure our recipient received the expected amount of WETH
        assertEq(WETH.balanceOf(alice), 1470000000000000000);

        // Our fee collector should have received 2%
        assertEq(WETH.balanceOf(feeCollector), 30000000000000000);
    }

    function test_CanClaimSpecificBribeRewardTokens() external disableClaimWindow {
        // Create 3 bribes in one epoch that contains different
        bytes32 merkleRoot = hex'2b52f18d66217640ead81dde7fa2e4f5fed97a3c4c437a43bb60434d326ba260';

        // Register our merkle roots
        _registerClaimWithThreeVotes(
            0, // epoch
            merkleRoot, // merkle root
            approvedCollection, // collection
            approvedCollection2, // collection
            approvedCollection3, // collection
            10 ether,
            10 ether,
            10 ether
        );

        uint[] memory includedBribeIds = new uint[](2);

        // Set up our bribe
        includedBribeIds[0] = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(2), 0.05 ether, 50 ether, emptyBlacklist);
        voteMarket.createBribe(approvedCollection2, address(WETH), epochManager.currentEpoch(), uint8(2), 0.05 ether, 50 ether, emptyBlacklist);
        includedBribeIds[1] = voteMarket.createBribe(approvedCollection3, address(WETH), epochManager.currentEpoch(), uint8(2), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProofA = new bytes32[](4);
        merkleProofA[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a0';
        merkleProofA[1] = hex'74d7830ae74d8644cc49789cd9bb46fb575885a4a171c0097a73ac90ef601a3b';
        merkleProofA[2] = hex'41500747f57a81a55fa547a74199f8f91ec0fccc40368c484ca4bfb139715b22';
        merkleProofA[3] = hex'b48cad943802515fe99b8f5ac78faf1ee49dc968cb28a3b79a546ded61bf8892';

        bytes32[] memory merkleProofB = new bytes32[](2);
        merkleProofB[0] = hex'67b678dfa4e907dd0430c40acc353661e30804047ebe925d836840157ebcc6eb';
        merkleProofB[1] = hex'a3eea3669f7417720e4fc640e3271c53871038e85cea2e7240dd05add9d839f7';

        uint[] memory epochs = new uint[](2);
        address[] memory collections = new address[](2);
        uint[] memory votes = new uint[](2);

        epochs[0] = 0;
        collections[0] = approvedCollection;
        votes[0] = 10 ether;
        merkleProofStore.push(merkleProofA);

        epochs[1] = 0;
        collections[1] = approvedCollection2;
        votes[1] = 10 ether;
        merkleProofStore.push(merkleProofB);

        // Specify the bribe IDs that we are collecting from in our call
        voteMarket.claim(alice, epochs, includedBribeIds, collections, votes, merkleProofStore);

        // Ensure our recipient received the expected amount of WETH, which should just include
        // just two claims of the possible three.
        assertEq(WETH.balanceOf(alice), 980000000000000000);

        // Our fee collector should have received 2%
        assertEq(WETH.balanceOf(feeCollector), 20000000000000000);
    }

    function test_CannotClaimTwiceOnSameCollectionEpoch() external disableClaimWindow {
        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        bytes32 merkleRoot = hex'4a504f2fee32fc23741019fe5681ab66a64e33bf5dccd9f7ead6b34e66d7623e';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRoot, approvedCollection, 10 ether);

        // Set up our bribe
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProof[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProof[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        // Our user has not yet claimed
        assertFalse(voteMarket.hasUserClaimed(bribeId, 0));

        // Claim as Alice with a valid request
        _claimAllWithSingleValues(alice, 0, approvedCollection, 10 ether, merkleProof);
        assertTrue(voteMarket.hasUserClaimed(bribeId, 0));

        // Attempt to claim as Alice again. The call won't fail, but will just not allow
        // an additional claim.
        _claimAllWithSingleValues(alice, 0, approvedCollection, 10 ether, merkleProof);
        assertTrue(voteMarket.hasUserClaimed(bribeId, 0));

        // Ensure we still only have the single expected transfer
        assertEq(WETH.balanceOf(alice), 490000000000000000);
        assertEq(WETH.balanceOf(feeCollector), 10000000000000000);
    }

    function test_CannotClaimIfBlacklisted() external {
        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        bytes32 merkleRoot = hex'4a504f2fee32fc23741019fe5681ab66a64e33bf5dccd9f7ead6b34e66d7623e';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRoot, approvedCollection, 10 ether);

        // Set up our bribe
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, aliceBlacklist);

        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProof[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProof[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        // Our user has not yet claimed
        assertFalse(voteMarket.hasUserClaimed(bribeId, 0));

        // Claim as Alice, which will keep the user claim as false and will not have
        // received any tokens.
        _claimAllWithSingleValues(alice, 0, approvedCollection, 10 ether, merkleProof);
        assertFalse(voteMarket.hasUserClaimed(bribeId, 0));

        // Ensure we still only have the single expected transfer
        assertEq(WETH.balanceOf(alice), 0);
        assertEq(WETH.balanceOf(feeCollector), 0);
    }

    function test_CanOnlyEarnTheEnforcedMaxRewardPerVote() external disableClaimWindow {
        // Our other tests show a number of votes that don't exceed the `maxRewardPerVote`, so this
        // test ensures that if a user is rewarded for more votes that the maximum price would give
        // against an epoch allocation then it just uses the number of total votes / total allocation.

        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 500 ether))
        bytes32 merkleRoot = hex'493bb15acdaa3558cafa78f98f658493736bc529fbedbda5e8cb66497c0f532d';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRoot, approvedCollection, 500 ether);

        // Set up our bribe so that we allocate 50 tokens to the bribe with a 1 token max reward
        // per vote. Since our user is providing 500 votes, this should reward the user with the
        // full 50 tokens, rather than 500 tokens which the max vote reward would calculate to.
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(1), 1 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = hex'9bce35978367d42a249f72fdf1c2d747b4e8ddf3c109d8021b5887ebf107ea9e';

        _claimAllWithSingleValues(alice, 0, approvedCollection, 500 ether, merkleProof);
        assertTrue(voteMarket.hasUserClaimed(bribeId, 0));

        // Ensure we still only have the single expected transfer
        assertEq(WETH.balanceOf(alice), 49 ether);
        assertEq(WETH.balanceOf(feeCollector), 1 ether);
    }

    function test_CanClaimDaoFeeAsExpected() external {
        // This functionality is included in other tests.
    }

    function test_CanRegisterClaims() external {
        // This functionality is included in other tests.
    }

    function test_CannotRegisterClaimsWithoutPermissions() external {
        vm.expectRevert('Unauthorized caller');
        voteMarket.registerClaims(0, keccak256('merkleRoot'), claimCollections, claimCollectionVotes);
    }

    function test_CanSetOracleWallet() external {
        assertEq(voteMarket.oracleWallet(), oracle);
        voteMarket.setOracleWallet(alice);
        assertEq(voteMarket.oracleWallet(), alice);
    }

    function test_CannotSetOracleWalletWithoutPermissions() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(alice);
        voteMarket.setOracleWallet(alice);

        assertEq(voteMarket.oracleWallet(), oracle);
    }

    function test_CannotExpireCollectionBribesWithoutPermissions() external {
        address[] memory collections = new address[](1);
        collections[0] = address(this);

        uint[] memory indexes = new uint[](1);
        indexes[0] = 0;

        vm.expectRevert('Unauthorized caller');
        voteMarket.expireCollectionBribes(collections, indexes);
    }

    function test_CanDefineClaimWindow(uint epoch) external {
        // Create a bribe on the current epoch, that lasts for 5 epochs.
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 25 ether, emptyBlacklist);

        /**
         * With our bribe running from epoch 0 to epoch 4 inclusive, and a claim window then lasting
         * for an additional 4 epochs, this gives us a claim window running from the start of epoch
         * 5, until the end of epoch 8. From epoch 9 onwards, the bribe creator will then be able
         * to withdraw any unclaimed amount and allocated users will no longer be able to claim.
         */

        // If we are in epoch 5, 6, 7 or 8, then we want to assert True, otherwise the window is
        // closed and will return False.
        epochManager.setCurrentEpoch(epoch);
        if (epoch == 5 || epoch == 6 || epoch == 7 || epoch == 8) {
            assertTrue(voteMarket.bribeClaimOpen(bribeId));
        }
        else {
            assertFalse(voteMarket.bribeClaimOpen(bribeId));
        }
    }

    function test_CannotClaimOutsideClaimWindow(uint epoch) external {
        /**
         * @dev The base version of this test in which the claim passes, is outlined in:
         * `test_CanClaimAgainstSingleCollectionOnOneEpoch`
         */

        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        bytes32 merkleRoot = hex'4a504f2fee32fc23741019fe5681ab66a64e33bf5dccd9f7ead6b34e66d7623e';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRoot, approvedCollection, 10 ether);

        // Set up our bribe
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProof[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProof[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        // Set up our claim
        uint[] memory bribeIds = new uint[](1);
        uint[] memory epochs = new uint[](1);
        address[] memory collections = new address[](1);
        uint[] memory votes = new uint[](1);

        bribeIds[0] = bribeId;
        epochs[0] = 0;
        collections[0] = approvedCollection;
        votes[0] = 10 ether;
        merkleProofStore.push(merkleProof);

        // Claim as Alice with a valid request.
        // @dev If we are in epoch 5, 6, 7 or 8, then we want to assert True, otherwise the
        //  window is closed and a revert will be raised.
        epochManager.setCurrentEpoch(epoch);
        if (epoch != 5 && epoch != 6 && epoch != 7 && epoch != 8) {
            vm.expectRevert('Claim window closed');
            voteMarket.claim(alice, epochs, bribeIds, collections, votes, merkleProofStore);

            // Ensure no claim was made for the recipient and no fees generated
            assertEq(WETH.balanceOf(alice), 0 ether);
            assertEq(WETH.balanceOf(feeCollector), 0 ether);
        }
        else {
            voteMarket.claim(alice, epochs, bribeIds, collections, votes, merkleProofStore);

            // Ensure our recipient received the expected amount of WETH
            assertEq(WETH.balanceOf(alice), 490000000000000000);

            // Our fee collector should have received 2%
            assertEq(WETH.balanceOf(feeCollector), 10000000000000000);
        }
    }

    function test_CanWithdrawUnclaimedBribeFunds() external {
        // Merkle Root
        // keccak256(abi.encode(alice, 0, approvedCollection, 10 ether))
        bytes32 merkleRoot = hex'4a504f2fee32fc23741019fe5681ab66a64e33bf5dccd9f7ead6b34e66d7623e';

        // Register our merkle root against epoch 0
        _registerClaimWithSingleVote(0, merkleRoot, approvedCollection, 10 ether);

        // Set up our bribe
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, emptyBlacklist);

        bytes32[] memory merkleProof = new bytes32[](3);
        merkleProof[0] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a1';
        merkleProof[1] = hex'8b21b8a5a775deda87741bf112ceaceacee044c477696c325e1c259cb2581b96';
        merkleProof[2] = hex'923010e87599b5969c1d6060a7da5b8c162fccbbd7d888258d195043b2f551a4';

        // Set our epoch to the claim window, allowing our user to make the claim
        epochManager.setCurrentEpoch(6);
        _claimAllWithSingleValues(alice, 0, approvedCollection, 10 ether, merkleProof);

        // Confirm our amounts before reclaims
        assertEq(WETH.balanceOf(alice), 490000000000000000);              // .49 eth
        assertEq(WETH.balanceOf(address(this)), 450_000000000000000000);  // 450 eth
        assertEq(WETH.balanceOf(feeCollector), 10000000000000000);        // .01 eth

        // Now we can move our epoch to after the claim window, so that the creator of the
        // bribe can withdraw their remaining bribe funds
        epochManager.setCurrentEpoch(9);
        voteMarket.reclaimExpiredFunds(bribeId);

        // Confirm our closing amounts
        assertEq(WETH.balanceOf(alice), 490000000000000000);             // .49 eth
        assertEq(WETH.balanceOf(address(this)), 499500000000000000000);  // 499.5 eth
        assertEq(WETH.balanceOf(feeCollector), 10000000000000000);       // .01 eth
    }

    function test_CannotWithdrawUnclaimedBribeFundsScenarios(uint epoch) external {
        // Set up our bribe
        uint bribeId = voteMarket.createBribe(approvedCollection, address(WETH), epochManager.currentEpoch(), uint8(5), 0.05 ether, 50 ether, emptyBlacklist);

        // Set our test epoch
        epochManager.setCurrentEpoch(epoch);

        // If we have an epoch before the bribe is set to end, then we sure get a revert
        // because the claim window has not yet closed
        if (epoch < 9) {
            vm.expectRevert('Too early to reclaim');
            voteMarket.reclaimExpiredFunds(bribeId);
        }

        // Otherwise, if we are past the claim window, then we should be able to claim
        // the funds remaining in the bribe
        else {
            voteMarket.reclaimExpiredFunds(bribeId);

            // We can also test that we can't reclaim funds more than once
            vm.expectRevert('No funds remaining');
            voteMarket.reclaimExpiredFunds(bribeId);
        }

        // Regardless of the epoch, we should not be able to make the call if we are
        // not the original creator of the bribe.
        vm.expectRevert('Not bribe creator');
        vm.prank(alice);
        voteMarket.reclaimExpiredFunds(bribeId);
    }

    function _registerClaimWithSingleVote(uint epoch, bytes32 root, address collection, uint votes) internal {
        claimCollections.push(collection);
        claimCollectionVotes.push(votes);

        vm.prank(oracle);
        voteMarket.registerClaims(epoch, root, claimCollections, claimCollectionVotes);
    }

    uint[] epochStore;
    address[] collectionStore;
    uint[] voteStore;
    bytes32[][] merkleProofStoreAlt;

    function _claimAllWithSingleValues(address account, uint epoch, address collection, uint votes, bytes32[] memory merkleProof)
        internal
    {
        epochStore.push(epoch);
        collectionStore.push(collection);
        voteStore.push(votes);
        merkleProofStoreAlt.push(merkleProof);

        voteMarket.claimAll(account, epochStore, collectionStore, voteStore, merkleProofStoreAlt);
    }

    function _registerClaimWithTwoVotes(uint epoch, bytes32 root, address collection1, address collection2, uint votes1, uint votes2)
        internal
    {
        claimCollections.push(collection1);
        claimCollections.push(collection2);
        claimCollectionVotes.push(votes1);
        claimCollectionVotes.push(votes2);

        vm.prank(oracle);
        voteMarket.registerClaims(epoch, root, claimCollections, claimCollectionVotes);
    }

    function _registerClaimWithThreeVotes(
        uint epoch,
        bytes32 root,
        address collection1,
        address collection2,
        address collection3,
        uint votes1,
        uint votes2,
        uint votes3
    ) internal {
        claimCollections.push(collection1);
        claimCollections.push(collection2);
        claimCollections.push(collection3);
        claimCollectionVotes.push(votes1);
        claimCollectionVotes.push(votes2);
        claimCollectionVotes.push(votes3);

        vm.prank(oracle);
        voteMarket.registerClaims(epoch, root, claimCollections, claimCollectionVotes);
    }

    /**
     * Allows our claim window to be disabled.
     */
    modifier disableClaimWindow() {
        vm.mockCall(
            address(voteMarket),
            abi.encodeWithSelector(VoteMarket.bribeClaimOpen.selector),
            abi.encode(true)
        );

        _;
    }
}
