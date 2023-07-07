// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Action} from '@floor/actions/Action.sol';

/**
 * This action allows us to send ETH.
 */
contract SendEth is Action {
    /**
     * Store our required information to action a swap.
     *
     * @param recipient The recipient of the ETH sent
     * @param amount The amount of ETH to send
     */
    struct ActionRequest {
        address payable recipient;
        uint amount;
    }

    /**
     * Sends a specific amount of ETH to a recipient.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH sent by the execution
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Ensure we have enough ETH sent in the request
        require(msg.value >= request.amount, 'Insufficient msg.value');

        // Transfer ETH to the {Treasury}
        (bool success,) = request.recipient.call{value: request.amount}('');
        require(success, 'Eth send fail');

        // If we have any ETH remaining in the contract we can return it to the sender
        unchecked {
            if (msg.value - request.amount != 0) {
                (success,) = msg.sender.call{value: msg.value - request.amount}('');
                require(success, 'Eth send fail');
            }
        }

        // Emit our `ActionEvent`
        emit ActionEvent('UtilsSendEth', _request);

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury}.
        return request.amount;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }
}
