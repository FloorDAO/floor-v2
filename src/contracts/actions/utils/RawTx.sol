// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IAction} from '@floor-interfaces/actions/Action.sol';

/**
 * This action allows us to send bytes to a recipient contract.
 */
contract RawTx is IAction {
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
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Action our call against the target recipient
        (bool success,) = request.recipient.call{value: msg.value}(request.data);
        require(success, 'Transaction failed');

        // If we have any ETH remaining in the contract we can return it to the sender
        uint balance = address(this).balance;
        if (balance != 0) {
            (success,) = msg.sender.call{value: balance}('');
            require(success, 'Refund of dust eth failed');
        }

        // We don't expect any response here, so just return zero value
        return 0;
    }

    /**
     * Allow us to receive any refunds from the transaction back into our account.
     */
    receive() external payable {
        //
    }

}
