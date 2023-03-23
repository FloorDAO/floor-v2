// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';

/// If Gem prevents our sweep from being successful
error UnableToSweepGem();

/**
 * @notice Allows sweeping from Gem.xyz to facilitate the purchasing and immediate
 * staking of ERC721s.
 *
 * @author Twade
 */
contract GemSweep is IAction, IERC721Receiver, Ownable, Pausable {
    /// Internal store of GemSwap contract
    address GEM_SWAP;

    /// @notice Emitted when ..
    event Sweep(uint ethAmount);

    /**
     * Executes a Gem.xyz sweep to facilitate the purchase of ERC721s.
     *
     * @param _request GemSwap transaction bytes
     *
     * @return uint The amount of ETH spent on the call
     */
    function execute(bytes calldata _request) public payable returns (uint spent) {
        // Sweeps from GemSwap
        (bool success,) = payable(GEM_SWAP).call{value: msg.value}(_request);
        if (!success) revert UnableToSweepGem();

        // Emit the amount of ETH used to sweep
        spent = msg.value - address(this).balance;
        emit Sweep(spent);

        // Return any remaining ETH
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * Allows the owner to add a whitelisted address that can be passed as a
     * `target` in the `sweepAndStake` function. This can be either activated
     * or deactivated based on the `_value` passed.
     */
    function setGemSwap(address _gemSwap) external onlyOwner {
        GEM_SWAP = _gemSwap;
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * Allows our contract to receive dust ETH back from our Gem sweep.
     */
    receive() external payable {}

}
