// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTXUnstakingInventoryZap {

    function setVaultFactory(address addr) external;

    function setInventoryStaking(address addr) external;

    function setSushiRouterAndWeth(address sushiRouterAddr) external;

    function unstakeInventory(uint256 vaultId, uint256 numNfts, uint256 remainingPortionToUnstake, address recipient) external payable;

    function maxNftsUsingXToken(uint256 vaultId, address staker, address slpToken) external view returns (uint256 numNfts, bool shortByTinyAmount);

    function rescue(address token) external;

}
