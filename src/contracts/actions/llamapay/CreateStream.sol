// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';

import {Action} from '@floor/actions/Action.sol';

/**
 * Creates and funds a stream on the Llamapay platform.
 */
contract LlamapayCreateStream is Action {
    /// Our internally deployed Llamapay router
    LlamapayRouter public immutable llamapayRouter;

    /**
     * Store our required information to action a stream creation.
     */
    struct ActionRequest {
        address to;
        address token;
        uint216 amountPerSec;
        uint amountToDeposit;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     */
    constructor(LlamapayRouter _llamapayRouter) {
        llamapayRouter = _llamapayRouter;
    }

    /**
     * Executes our request to create and fund a stream.
     *
     * @dev If the Llamapay token contract does not yet exist, then additional gas will
     * be required to create it. For common tokens like USDC, this won't occur.
     *
     * @param _request Bytes to be cast to the `ActionRequest` struct
     *
     * @return uint Total balance currently held by the stream
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Emit our `ActionEvent`
        emit ActionEvent('LlamapayCreateStream', _request);

        return llamapayRouter.createStream(msg.sender, request.to, request.token, request.amountToDeposit, uint216(request.amountPerSec));
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }
}
