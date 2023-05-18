// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {LSSVMPair} from '@sudoswap/LSSVMPair.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';

/**
 * Sends a set of NFTs to the pair in exchange for token
 *
 * @dev To compute the amount of token to that will be received, call
 * `bondingCurve.getSellInfo`.
 */
contract SudoswapSellNftsForEth is IAction {
    /**
     * Store our required information to action a sell.
     *
     * @param nftIds The list of IDs of the NFTs to sell to the pair
     * @param minExpectedTokenOutput The minimum acceptable token received by the sender. If
     * the actual amount is less than this value, the transaction will be reverted.
     * @param tokenRecipient The recipient of the token output
     * @param isRouter True if calling from LSSVMRouter, false otherwise. Not used for
     * ETH pairs.
     * @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this
     * address. Not used for ETH pairs.
     */
    struct ActionRequest {
        address pair;
        uint[] nftIds;
        uint minExpectedTokenOutput;
    }

    /**
     * TODO: ...
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH or ERC20 spent on the execution
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into individual variables, as mapping it directly
        // to the struct is buggy due to memory -> storage array mapping.
        (address pair, uint[] memory nftIds, uint minExpectedTokenOutput) = abi.decode(_request, (address, uint[], uint));

        // Get the NFT from the pairing
        IERC721 nft = LSSVMPair(pair).nft();

        // We need to pull in all of the NFTs into the action to send it to the pairing
        uint length = nftIds.length;
        for (uint i; i < length;) {
            nft.transferFrom(msg.sender, address(this), nftIds[i]);
            nft.approve(pair, nftIds[i]);
            unchecked {
                ++i;
            }
        }

        // Sell the NFTs and send the tokens to the sender
        return LSSVMPair(pair).swapNFTsForToken({
            nftIds: nftIds,
            minExpectedTokenOutput: minExpectedTokenOutput,
            tokenRecipient: payable(msg.sender),
            isRouter: false,
            routerCaller: msg.sender
        });
    }
}
