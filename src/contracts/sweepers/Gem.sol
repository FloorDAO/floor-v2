// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Interacts with the Gem.xyz protocol to fulfill a sweep order.
 */
contract GemSweeper is ISweeper, Ownable {
    /// The Gem Swap contract that will be called for the sweep
    address payable public gemSwap;

    /**
     * Passes the request data to the `gemSwap` contract to action and refunds any
     * remaining ETH.
     */
    function execute(address[] calldata, /* collections */ uint[] calldata, /* amounts */ bytes calldata data)
        external
        payable
        override
        returns (string memory)
    {
        // Confirm that a GemSwap contract has been set
        require(gemSwap != address(0), 'No GemSwap contract set');

        // Sweeps from GemSwap
        (bool success,) = payable(gemSwap).call{value: msg.value}(data);
        require(success, 'Unable to sweep');

        // Return any remaining ETH
        payable(msg.sender).transfer(address(this).balance);

        // Return an empty string as no message to store
        return '';
    }

    /**
     * Allows our Gem contract to be set
     */
    function setGemSwapContract(address payable _gemSwap) external onlyOwner {
        gemSwap = _gemSwap;
    }

    /**
     * Allows our contract to receive dust ETH back from our Gem sweep.
     */
    receive() external payable {}
}
