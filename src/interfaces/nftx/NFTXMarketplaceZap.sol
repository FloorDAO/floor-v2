// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXMarketplaceZap {

    function mintAndSell721(uint vaultId, uint[] calldata ids, uint minEthOut, address[] calldata path, address to) external;

    function buyAndRedeem(uint vaultId, uint amount, uint[] calldata specificIds, address[] calldata path, address to) external payable;

}
