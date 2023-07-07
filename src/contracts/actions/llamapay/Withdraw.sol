// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';

import {Action} from '@floor/actions/Action.sol';

/**
 * Withdraws tokens from a Llamapay pool.
 */
contract LlamapayWithdraw is Action {
    /// Our internally deployed Llamapay router
    LlamapayRouter public immutable llamapayRouter;

    /**
     * Store our required information to action a withdrawal.
     */
    struct ActionRequest {
        address token;
        uint amount;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     */
    constructor(LlamapayRouter _llamapayRouter) {
        llamapayRouter = _llamapayRouter;
    }

    /**
     * Executes our token withdrawal against our Llamapay router.
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Emit our `ActionEvent`
        emit ActionEvent('LlamapayWithdraw', _request);

        return llamapayRouter.withdraw(msg.sender, request.token, request.amount);
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }
}
