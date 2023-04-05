// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IVault} from '@floor-interfaces/vaults/Vault.sol';

/**
 * ..
 */
contract FloorDepositIntoVault is IAction {

    /**
     * Store our required information to action a swap.
     *
     * ..
     */
    struct ActionRequest {
        address vault;
        address token;
        uint amount;
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Ensure that we have an amount sent
        require(request.amount != 0, 'Invalid amount');

        // Deposit the requested token into the vault. This assumes that the {Treasury}
        // has already approved the asset to be deposited.
        return IVault(request.vault).deposit(request.token, request.amount);
    }

}
