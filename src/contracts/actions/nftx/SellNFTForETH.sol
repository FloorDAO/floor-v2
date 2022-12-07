// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import '../../../interfaces/nftx/NFTXMarketplaceZap.sol';


contract NFTXSellNFTForETH {

    /// ..
    INFTXMarketplaceZap public immutable marketplaceZap;

    /// Our WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The {Treasury} contract that will be the funder of the funds and
    /// the recipient of the swapped WETH.
    address public immutable treasury;

    /**
     * Store our required information to action a swap.
     */
    struct ActionRequest {
        address asset;
        uint vaultId;
        uint[] tokenIds;
        uint minEthOut;
        address[] path;
    }

    /**
     * Stores the amount of WETH generated from the swap.
     */
    struct ActionResponse {
        uint256 amountOut;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     */
    constructor (address _marketplaceZap, address _treasury) {
        marketplaceZap = INFTXMarketplaceZap(_marketplaceZap);
        treasury = _treasury;
    }

    /**
     *
     */
    function execute(ActionRequest calldata request) public returns (ActionResponse memory) {
        // Ensure that we have tokenIds sent
        uint256 length = request.tokenIds.length;
        require(length != 0);

        // TODO: Expand support to 1155 and PUNKs
        for (uint i; i < length;) {
            ERC721(request.asset).safeTransferFrom(msg.sender, address(this), request.tokenIds[i]);
            unchecked { ++i; }
        }

        // Now that the tokens are held in our contract we can approve the marketplace zap
        // to use them.
        ERC721(request.asset).setApprovalForAll(address(marketplaceZap), true);

        // Take a snapshot of our starting balance to calculate the end balance difference
        uint startBalance = address(treasury).balance;

        // Set up our swap parameters based on `execute` parameters
        marketplaceZap.mintAndSell721(
            request.vaultId,
            request.tokenIds,
            request.minEthOut,
            request.path,
            treasury
        );

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury} during the swap itself.
        return ActionResponse({
            amountOut: address(treasury).balance - startBalance
        });
    }

    /**
     *
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
