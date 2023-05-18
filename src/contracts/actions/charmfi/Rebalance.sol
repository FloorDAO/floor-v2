// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IStrategy} from '@charmfi/interfaces/IStrategy.sol';

import {Action} from '@floor/actions/Action.sol';

/**
 * Updates vault's positions. Can only be called by the strategy keeper.
 *
 * @dev Two orders are placed - a base order and a limit order. The base
 * order is placed first with as much liquidity as possible. This order
 * should use up all of one token, leaving only the other one. This excess
 * amount is then placed as a single-sided bid or ask order.
 */
contract CharmRebalance is Action {
    struct ActionRequest {
        address strategy;
    }

    /**
     * Calculates new ranges for orders and calls `vault.rebalance()` so that vault can
     * update its positions.
     *
     * @dev Can only be called by keeper.
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct and call our internal execute logic
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        if (IStrategy(request.strategy).shouldRebalance()) {
            IStrategy(request.strategy).rebalance();
        }

        return 0;
    }
}
