// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

/**
 * Allows for approved ERC20 tokens to be deposited into a vault.
 */
contract FloorDepositIntoVault is IAction {

    /**
     * Store our required information to action a swap.
     *
     * @param vault The address of the vault that will receive the deposit
     * @param token The token to be deposited into the vault
     * @param amount The amount of tokens to be deposited
     */
    struct ActionRequest {
        address vault;
        address[] tokens;
        uint[] amounts;
    }

    /**
     * Takes a token and amount, and deposits it into a specified vault.
     *
     * @dev This assumes that the sender has already approved the asset.
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Deposit the requested token into the vault. This assumes that the {Treasury}
        // has already approved the asset to be deposited.
        IBaseStrategy(request.vault).deposit(request.tokens, request.amounts);

        return 0;
    }

}
