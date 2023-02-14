// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {VoteMarket} from '../../src/contracts/bribes/VoteMarket.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract VoteMarketTest is FloorTest {

    address alice;
    address feeCollector;
    address oracle;

    VoteMarket voteMarket;

    constructor() {
        // Set up a small pool of test users
        (alice, feeCollector, oracle) = (users[0], users[1], users[2]);

        voteMarket = new VoteMarket(oracle);
    }

    function test_CanCreateBribe() external {
        // ..
    }

    function test_CannotCreateBribeWithZeroAddressRewardToken() external {
        // ..
    }

    function test_CannotCreateBribeUnderMinimumEpochs() external {
        // ..
    }

    function test_CannotCreateBribeWithZeroTotalRewards() external {
        // ..
    }

    function test_CannotCreateBribeWithZeroMaxRewardPerVote() external {
        // ..
    }

    function test_CannotCreateBribeWithoutSufficientTokens() external {
        // ..
    }

    function test_CanClaimAgainstSingleCollectionOnOneEpoch() external {
        // ..
    }

    function test_CanClaimAgainstSingleCollectionOverMultipleEpochs() external {
        // ..
    }

    function test_CanClaimAgainstMultipleCollections() external {
        // ..
    }

    function test_CannotClaimTwiceOnSameCollectionEpoch() external {
        // ..
    }

    function test_CannotClaimIfBlacklisted() external {
        // ..
    }

    function test_CanOnlyEarnTheEnforcedMaxRewardPerVote() external {
        // ..
    }

    function test_CanClaimDaoFeeAsExpected() external {
        // ..
    }

    function test_CanRegisterClaims() external {
        // ..
    }

    function test_CannotRegisterClaimsWithoutPermissions() external {
        vm.expectRevert('Unauthorized caller');
        voteMarket.registerClaims(0, keccak256('merkleRoot'));
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

    function test_CanExpireCollectionBribes() external {
        // ..
    }

    function test_CannotExpireCollectionBribesWithoutPermissions() external {
        address[] memory collections = new address[](1);
        collections[0] = address(this);

        uint[] memory indexes = new uint[](1);
        indexes[0] = 0;

        vm.expectRevert('Unauthorized caller');
        voteMarket.expireCollectionBribes(collections, indexes);
    }


}
