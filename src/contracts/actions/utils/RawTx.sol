// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Action} from '@floor/actions/Action.sol';

/**
 * This action allows us to send bytes to a recipient contract.
 */
contract RawTx is Action {
    /**
     * Store our required information to action a raw transaction.
     *
     * @param recipient The recipient of the ETH sent
     * @param data The bytes data to be sent in the call
     */
    struct ActionRequest {
        address payable recipient;
        bytes data;
    }

    /**
     * Sends a specific amount of ETH to a recipient.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        (address payable recipient, bytes memory data) = abi.decode(_request, (address, bytes));

        // Action our call against the target recipient
        (bool success,) = recipient.call{value: msg.value}(data);
        require(success, 'Transaction failed');

        // If we have any ETH remaining in the contract we can return it to the sender
        uint balance = address(this).balance;
        if (balance != 0) {
            (success,) = msg.sender.call{value: balance}('');
            require(success, 'Refund of dust eth failed');
        }

        // Emit our `ActionEvent`
        emit ActionEvent('UtilsRawTx', _request);

        // We don't expect any response here, so just return zero value
        return 0;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes calldata _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    /**
     * Allow us to receive any refunds from the transaction back into our account.
     */
    receive() external payable {}
}
