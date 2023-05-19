// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAction} from '@floor-interfaces/actions/Action.sol';

/**
 * Provides a function to batch together multiple calls in a single external call.
 */
contract ActionMulticall {
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     */
    function multicall(address[] calldata actions, bytes[] calldata data) external virtual {
        uint length = actions.length;
        for (uint i; i < length;) {
            IAction(actions[i]).execute(data[i]);
            unchecked {
                ++i;
            }
        }
    }
}
