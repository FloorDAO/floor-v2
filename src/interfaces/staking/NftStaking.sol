// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftStaking {

    /// Emitted when a token is staked
    event TokensStaked(address sender, uint tokens, uint tokenValue, uint currentEpoch, uint8 epochCount);

    /// Emitted when a token is unstaked
    event TokensUnstaked(address sender, uint numNfts, uint remainingPortionToUnstake, uint fees);

    function collectionStakerIndex(bytes32) external returns (uint);

    function voteDiscount() external returns (uint16);

    function sweepModifier() external returns (uint64);

    function collectionBoost(address _collection) external view returns (uint boost_);

    function collectionBoost(address _collection, uint _epoch) external view returns (uint boost_);

    function stake(address _collection, uint[] calldata _tokenId, uint8 _epochCount) external;

    function unstake(address _collection) external;

    function unstakeFees(address _collection) external returns (uint);

    function setVoteDiscount(uint16 _voteDiscount) external;

    function setSweepModifier(uint64 _sweepModifier) external;

    function setPricingExecutor(address _pricingExecutor) external;

    function setBoostCalculator(address _boostCalculator) external;

    function claimRewards(address _collection) external;

}
