// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Interacts with the Gem.xyz protocol to fulfill a sweep order.
 */
contract GemSweeper is ISweeper {

    function execute(
        address[] calldata /* collections */,
        uint[] calldata /* amounts */,
        bytes calldata data
    ) external payable override returns (string memory) {
        // Unpack the call data into sweep data
        (address gemSwap, bytes memory request) = abi.decode(data, (address, bytes));

        // Sweeps from GemSwap
        (bool success,) = payable(gemSwap).call{value: msg.value}(request);
        require(success, 'Unable to sweep');

        // Return any remaining ETH
        payable(msg.sender).transfer(address(this).balance);

        // Return an empty string as no message to store
        return '';
    }

    /**
     * Allows our contract to receive dust ETH back from our Gem sweep.
     */
    receive() external payable {}

}
