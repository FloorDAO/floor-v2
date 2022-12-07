// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface INFTXMarketplaceZap {

    function mintAndSell721(
        uint256 vaultId,
        uint256[] calldata ids,
        uint256 minEthOut,
        address[] calldata path,
        address to
    ) external;

}
