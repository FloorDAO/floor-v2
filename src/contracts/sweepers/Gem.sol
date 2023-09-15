// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import {CannotSetNullAddress, TransferFailed} from '@floor/utils/Errors.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Interacts with the Gem.xyz protocol to fulfill a sweep order.
 */
contract GemSweeper is ISweeper, Ownable, ReentrancyGuard {
    /// Emitted when the GemSwap contract is updated
    event GemSwapContractUpdated(address gemSwap);

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
        nonReentrant
        returns (string memory)
    {
        // Confirm that a GemSwap contract has been set
        require(gemSwap != address(0), 'No GemSwap contract set');

        // Sweeps from GemSwap
        (bool success,) = payable(gemSwap).call{value: msg.value}(data);
        require(success, 'Unable to sweep');

        // Return any remaining ETH
        (success,) = msg.sender.call{value: address(this).balance}('');
        if (!success) revert TransferFailed();

        // Return an empty string as no message to store
        return '';
    }

    /**
     * Allows our Gem contract to be set
     */
    function setGemSwapContract(address payable _gemSwap) external onlyOwner {
        if (_gemSwap == address(0)) revert CannotSetNullAddress();
        gemSwap = _gemSwap;
        emit GemSwapContractUpdated(_gemSwap);
    }

    /**
     * Specify that only a TREASURY_MANAGER can run this sweeper.
     */
    function permissions() public pure override returns (bytes32) {
        return keccak256('TreasuryManager');
    }

    /**
     * Allows our contract to receive dust ETH back from our Gem sweep.
     */
    receive() external payable {}
}
