// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Allows a sweep to be referenced as manually swept outside of onchain logic. This references
 * another transaction to provide information that the sweep was completed.
 *
 * This can be used to allow for multiple fractional sweeps from multiple epoch votes to be
 * completed in a single transaction.
 */
contract ManualSweeper is ISweeper {

    /**
     * Our execute function call will just return the provided bytes data that should unpack
     * into a string message to be subsequently stored onchain against the sweep.
     */
    function execute(
        address[] calldata /* collections */,
        uint[] calldata /* amounts */,
        bytes calldata data
    ) external payable override returns (string memory) {
        return string(data);
    }

}