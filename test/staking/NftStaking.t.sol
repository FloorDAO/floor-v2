// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../utilities/Environments.sol';

contract NftStakingTest is FloorTest {

    constructor () {}

    function test_CannotDeployContractWithInvalidParameters() external {}

    function test_CanGetUserBoostWhenZero() external {}
    function test_CanGetUserBoostWithSingleCollection() external {}
    function test_CanGetUserBoostWithMultipleCollections() external {}
    function test_CanStakeSingleNft() external {}
    function test_CanStakeMultipleNfts() external {}
    function test_CannotStakeUnownedNft() external {}
    function test_CannotStakeInvalidCollectionNft() external {}
    function test_CannotStakeNftForInvalidEpochCount() external {}

    function test_CanUnstakeSingleToken() external {}
    function test_CanUnstakeMultipleTokens() external {}
    function test_CannotUnstakeFromUnknownCollection() external {}
    function test_CannotUnstakeFromCollectionWithInsufficientPosition() external {}

    function test_CanSetVoteDiscount() external {}
    function test_CannotSetInvalidVoteDiscount() external {}

    function test_CanSetPricingExecutor() external {}
    function test_CannotSetInvalidPricingExecutor() external {}

    function test_CanSetStakingZaps() external {}
    function test_CannotSetInvalidStakingZaps() external {}

    function test_CanClaimRewards() external {}

}
