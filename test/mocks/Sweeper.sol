// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Interacts with the Gem.xyz protocol to fulfill a sweep order.
 */
contract SweeperMock is ISweeper {
    function execute(address[] calldata, /* collections */ uint[] calldata, /* amounts */ bytes calldata /* data */ )
        external
        payable
        override
        returns (string memory)
    {
        // Return an empty string as no message to store
        return '';
    }
}
