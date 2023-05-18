// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';

/**
 * Makes a deposit into a Llamapay pool. This subsidises salary and other outgoing
 * payments to the team and external third parties.
 */
contract LlamapayDeposit is IAction, Pausable {
    /// Our internally deployed Llamapay router
    LlamapayRouter public immutable llamapayRouter;

    /**
     * Store our required information to action a deposit.
     */
    struct ActionRequest {
        address token;
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
     * Executes our token deposit against our Llamapay router.
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));
        return llamapayRouter.deposit(msg.sender, request.token, request.amountToDeposit);
    }
}
