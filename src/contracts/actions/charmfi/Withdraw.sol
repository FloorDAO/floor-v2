// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from '@charmfi/interfaces/IVault.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';


/**
 * Withdraws tokens in proportion to the vault's holdings.
 */
contract CharmWithdraw is IAction {

    /// @param shares Shares burned by sender
    /// @param amount0Min Revert if resulting `amount0` is smaller than this
    /// @param amount1Min Revert if resulting `amount1` is smaller than this
    struct ActionRequest {
        uint shares;
        uint amount0Min;
        uint amount1Min;
        address vault;
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Burns liquidity stated, amount0Min and amount1Min are the least you get for
        // burning that liquidity (else reverted).
        IVault(request.vault).withdraw({
            shares: request.shares,
            amount0Min: request.amount0Min,
            amount1Min: request.amount1Min,
            to: msg.sender
        });

        return 0;
    }

}
