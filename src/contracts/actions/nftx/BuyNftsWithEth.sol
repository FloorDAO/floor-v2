// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {Action} from '@floor/actions/Action.sol';
import {INFTXMarketplaceZap} from '@floor-interfaces/nftx/NFTXMarketplaceZap.sol';

/**
 * This action allows us to batch sell ERC721 NFT tokens from the {Treasury}
 * into a specific NFTX vault.
 *
 * This uses the NFTX Marketplace Zap to facilitate the trade, allowing us to
 * specify a minimum amount of ETH to receive in return.
 */
contract NFTXBuyNftsWithEth is Action {
    /// The NFTX Marketplace Zap contract
    INFTXMarketplaceZap public immutable marketplaceZap;

    /// Stores our NFT recipient so that we can hook into safe transfer callbacks
    address private _nftReceiver;

    /**
     * Store our required information to action a buy.
     *
     * @param vaultId ID of the vault being interacted with
     * @param amount The number of NFTs to buy
     * @param specificIds Optional specific IDs to redeem, if any
     * @param path The generated exchange path
     */
    struct ActionRequest {
        uint vaultId;
        uint amount;
        uint[] specificIds;
        address[] path;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     *
     * @param _marketplaceZap Address of the NFTX Marketplace Zap
     */
    constructor(address _marketplaceZap) {
        marketplaceZap = INFTXMarketplaceZap(_marketplaceZap);
    }

    /**
     * Buys an `amount` of ERC721 tokens from the NFTX vault collection.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH spent on the execution
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into individual variables, as mapping it directly
        // to the struct is buggy due to memory -> storage array mapping.
        (uint vaultId, uint amount, uint[] memory specificIds, address[] memory path) =
            abi.decode(_request, (uint, uint, uint[], address[]));

        // Take a snapshot of our starting balance to calculate the end balance difference
        uint startBalance = address(this).balance;

        _nftReceiver = msg.sender;

        // Set up our swap parameters based on `execute` parameters
        marketplaceZap.buyAndRedeem{value: msg.value}(vaultId, amount, specificIds, path, msg.sender);

        delete _nftReceiver;

        // Get the remaining ETH and transfer it back to the sender
        uint remainingBalance = startBalance - msg.value + address(this).balance;
        if (remainingBalance != 0) {
            (bool success,) = payable(msg.sender).call{value: remainingBalance}('');
            require(success, 'Cannot refund ETH');
        }

        // Emit our `ActionEvent`
        emit ActionEvent('NftxBuyNftsWithEth', _request);

        // We return just the amount of tokens bought
        return amount;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    /**
     * Allows the contract to receive ERC721 tokens from our {Treasury}.
     */
    function onERC721Received(address, address, uint tokenId, bytes memory) public virtual returns (bytes4) {
        if (_nftReceiver != address(0)) {
            IERC721(msg.sender).safeTransferFrom(address(this), _nftReceiver, tokenId);
        }
        return this.onERC721Received.selector;
    }
}
