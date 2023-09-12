// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';

/**
 * Handles our core action logic that each action should inherit.
 */
abstract contract Action is IAction, Ownable, Pausable {
    /// Emitted when an action is processed, including relevant information.
    event ActionEvent(string indexed logName, bytes data);

    /**
     * Stores the executed code for the action.
     */
    function execute(bytes calldata /* _request */ ) public payable virtual whenNotPaused returns (uint) {
        revert('Not implemented');
    }

    /**
     * Pauses execution functionality.
     *
     * @param _p Boolean value for if the action should be paused
     */
    function pause(bool _p) external onlyOwner {
        if (_p) _pause();
        else _unpause();
    }
}
