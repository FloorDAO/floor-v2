// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20, LSSVMPair} from '@sudoswap/LSSVMPair.sol';
import {LSSVMPairERC20} from '@sudoswap/LSSVMPairERC20.sol';

import {Action} from '@floor/actions/Action.sol';

/**
 * Sends token to the pair in exchange for any `numNFTs` NFTs.
 */
contract SudoswapBuyNftsWithEth is Action {
    /// Temporary store for a fallback ETH recipient
    address ethRecipient;

    /**
     * Store our required information to action a buy.
     *
     * @param pair The address of the Sudoswap token pair
     * @param numNFTs The number of NFTs to purchase
     * @param maxExpectedTokenInput The maximum acceptable cost from the sender. If the actual
     * amount is greater than this value, the transaction will be reverted.
     * @param nftRecipient The recipient of the NFTs
     */
    struct ActionRequest {
        address pair;
        uint numNFTs;
        uint maxExpectedTokenInput;
        address nftRecipient;
    }

    /**
     * Buys one or more NFTs from a Sudoswap pool using the paired token.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return spent The amount of ETH or ERC20 spent on the execution
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint spent) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // If we are calling an ERC20 pairing, then we need to pull our tokens
        // into this action contract.
        if (LSSVMPair(request.pair).poolType() == LSSVMPair.PoolType.TRADE) {
            ERC20 token = LSSVMPairERC20(request.pair).token();
            token.transferFrom(msg.sender, address(this), request.maxExpectedTokenInput);
            token.approve(address(request.pair), request.maxExpectedTokenInput);

            spent = LSSVMPair(request.pair).swapTokenForAnyNFTs({
                numNFTs: request.numNFTs,
                maxExpectedTokenInput: request.maxExpectedTokenInput,
                nftRecipient: request.nftRecipient,
                isRouter: false,
                routerCaller: address(0)
            });

            // Transfer the unspent back tokens to the recipient
            if (spent < request.maxExpectedTokenInput) {
                token.transfer(msg.sender, request.maxExpectedTokenInput - spent);
            }
        } else if (LSSVMPair(request.pair).poolType() == LSSVMPair.PoolType.NFT) {
            // Set our recipient for any returned ETH
            ethRecipient = msg.sender;

            spent = LSSVMPair(request.pair).swapTokenForAnyNFTs{value: msg.value}({
                numNFTs: request.numNFTs,
                maxExpectedTokenInput: request.maxExpectedTokenInput,
                nftRecipient: request.nftRecipient,
                // By setting the sender as a router, the ERC20 tokens are transferred
                // directly from the origin user.
                isRouter: true,
                routerCaller: msg.sender
            });

            // Remove our refunded ETH recipient
            delete ethRecipient;
        } else {
            revert('Unknown pool type');
        }

        // Emit our `ActionEvent`
        emit ActionEvent('SudoswapBuyNftsWithEth', _request);
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    receive() external payable {
        require(ethRecipient != address(0), 'Invalid ETH recipient');
        payable(ethRecipient).transfer(msg.value);
    }
}
