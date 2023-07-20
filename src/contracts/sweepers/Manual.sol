// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Allows a sweep to be referenced as manually swept outside of onchain logic. This references
 * another transaction to provide information that the sweep was completed.
 *
 * This can be used to allow for multiple fractional sweeps from multiple epoch votes to be
 * completed in a single transaction.
 *
 * @dev The Manual Sweeper shouldn't receive ETH as part of the process as it should just allow
 * a tx code to be passed in. This sweeper would assume that the sweeping would be done
 * externally and this would just provide reference to the external sweep. For example, if we
 * were to sweep OTC, then we may just link to the tx.
 */
contract ManualSweeper is ISweeper {
    /**
     * Our execute function call will just return the provided bytes data that should unpack
     * into a string message to be subsequently stored onchain against the sweep.
     */
    function execute(address[] calldata /* collections */, uint[] calldata /* amounts */, bytes calldata data)
        external
        payable
        override
        returns (string memory)
    {
        // Ensure that no ETH is sent in the call
        require(msg.value == 0, 'ETH should not be sent in call');

        // Ensure that we have been provided data parameters
        require(data.length != 0, 'Invalid data parameter');
        return string(data);
    }
}
