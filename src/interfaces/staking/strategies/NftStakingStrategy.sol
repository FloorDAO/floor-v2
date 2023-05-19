// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INftStakingStrategy {
    function approvalAddress() external view returns (address);

    function stake(address _user, address _collection, uint[] calldata _tokenId, uint[] calldata _amounts, bool _is1155) external;
    function unstake(address recipient, address _collection, uint numNfts, uint baseNfts, uint remainingPortionToUnstake, bool _is1155)
        external;

    function rewardsAvailable(address _collection) external returns (uint);
    function claimRewards(address _collection) external returns (uint);

    function underlyingToken(address _collection) external view returns (address);
    function setUnderlyingToken(address _collection, address _token, address _xToken) external;

    function onERC721Received(address, address, uint, bytes memory) external returns (bytes4);
}
