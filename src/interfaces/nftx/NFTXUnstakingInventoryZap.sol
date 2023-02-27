// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface INFTXUnstakingInventoryZap {

    function unstakeInventory(uint256 vaultId, uint256 numNfts, uint256 remainingPortionToUnstake) external payable;

    function maxNftsUsingXToken(uint256 vaultId, address staker, address slpToken) external returns (uint256 numNfts, bool shortByTinyAmount);
}
