// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';

interface INftStakingStrategy {

    function approvalAddress() external view returns (address);

    function stake(address _user, address _collection, uint[] calldata _tokenId) external;
    function unstake(address recipient, address _collection, uint numNfts, uint remainingPortionToUnstake) external;
    function claimRewards(address _collection) external;

    function underlyingToken(address _collection) external view returns (address);
    function setUnderlyingToken(address _collection, address _token, address _xToken) external;

    function onERC721Received(address, address, uint, bytes memory) external returns (bytes4);

}
