// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftStaking {

    function underlyingTokenMapping(address) external returns (address);

    function stakingEpochStart(bytes32) external returns (uint);

    function stakingEpochCount(bytes32) external returns (uint);

    function userTokensStaked(bytes32) external returns (uint);

    function collectionStakerIndex(bytes32) external returns (uint);

    function voteDiscount() external returns (uint);

    function sweepModifier() external returns (uint);

    function currentEpoch() external returns (uint);

    function collectionBoost(address _collection) external view returns (uint boost_);

    function collectionBoost(address _collection, uint _epoch) external view returns (uint boost_);

    function stake(address _collection, uint[] calldata _tokenId, uint _epochCount) external;

    function unstake(address _collection) external;

    function unstakeFees(address _collection) external returns (uint);

    function setVoteDiscount(uint _voteDiscount) external;

    function setSweepModifier(uint _sweepModifier) external;

    function setPricingExecutor(address _pricingExecutor) external;

    function setStakingZaps(address _stakingZap, address _unstakingZap) external;

    function setUnderlyingToken(address _collection, address _token, address _xToken) external;

    function setCurrentEpoch(uint _currentEpoch) external;

    function setBoostCalculator(address _boostCalculator) external;

    function claimRewards(address _collection) external;

    function onERC721Received(address, address, uint, bytes memory) external returns (bytes4);

}