// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXUnstakingInventoryZap {
    function unstakeInventory(uint vaultId, uint numNfts, uint remainingPortionToUnstake) external payable;

    function maxNftsUsingXToken(uint vaultId, address staker, address slpToken) external returns (uint numNfts, bool shortByTinyAmount);
}
