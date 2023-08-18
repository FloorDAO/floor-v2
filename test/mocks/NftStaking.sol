// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';
import {INftStakingStrategy} from '@floor-interfaces/staking/strategies/NftStakingStrategy.sol';
import {INftStakingBoostCalculator} from '@floor-interfaces/staking/calculators/NftStakingBoostCalculator.sol';

/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting through the calculation of a multiplier.
 */

contract NftStakingMock is INftStaking {

    function collectionStakerIndex(bytes32) external returns (uint) {}

    function voteDiscount() external returns (uint16) {
        return 0;
    }

    function sweepModifier() external returns (uint64) {
        return 0;
    }

    function collectionBoost(address _collection, int _votes) external view returns (int votes_) {
        votes_ = _votes;
    }

    function stake(address _collection, uint[] calldata _tokenId, uint[] calldata _amount, uint8 _epochCount, bool _is1155) external pure {}

    function unstake(address _collection, bool _is1155) external pure {}

    function unstake(address _collection, address _nftStakingStrategy, bool _is1155) external pure {}

    function unstakeFees(address _collection) external pure returns (uint) {
        return 0;
    }

    function setVoteDiscount(uint16 _voteDiscount) external pure {}

    function setSweepModifier(uint64 _sweepModifier) external pure {}

    function setPricingExecutor(address _pricingExecutor) external pure {}

    function setBoostCalculator(address _boostCalculator) external pure {}

    function claimRewards(address _collection) external pure {}
}
