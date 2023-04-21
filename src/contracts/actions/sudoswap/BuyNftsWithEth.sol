// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20, LSSVMPair} from '@sudoswap/LSSVMPair.sol';
import {LSSVMPairERC20} from '@sudoswap/LSSVMPairERC20.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';


/**
 * Sends token to the pair in exchange for any `numNFTs` NFTs.
 *
 * @dev To compute the amount of token to send, call bondingCurve.getBuyInfo. This swap
 * function is meant for users who are ID agnostic.
 */
contract SudoswapBuyNftsWithEth is IAction {

    /**
     * Store our required information to action a buy.
     *
     * @param numNFTs The number of NFTs to purchase
     * @param maxExpectedTokenInput The maximum acceptable cost from the sender. If the actual
     * amount is greater than this value, the transaction will be reverted.
     * @param nftRecipient The recipient of the NFTs
     * @param isRouter True if calling from LSSVMRouter, false otherwise. Not used for
     * ETH pairs.
     * @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this
     * address. Not used for ETH pairs.
     */
    struct ActionRequest {
        address pair;
        uint numNFTs;
        uint maxExpectedTokenInput;
        address nftRecipient;
        bool isRouter;
        address routerCaller;
    }

    /**
     * TODO: ...
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH or ERC20 spent on the execution
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // If we are calling an ERC20 pairing, then we need to pull our tokens
        // into this action contract.
        if (LSSVMPair(request.pair).poolType() == LSSVMPair.PoolType.TOKEN) {
            ERC20 token = LSSVMPairERC20(request.pair).token();
            token.transferFrom(msg.sender, address(this), request.maxExpectedTokenInput);
            token.approve(address(request.pair), request.maxExpectedTokenInput);
        }

        return LSSVMPair(request.pair).swapTokenForAnyNFTs{value: msg.value}({
            numNFTs: request.numNFTs,
            maxExpectedTokenInput: request.maxExpectedTokenInput,
            nftRecipient: msg.sender,
            isRouter: request.isRouter,
            routerCaller: request.routerCaller
        });
    }

}
