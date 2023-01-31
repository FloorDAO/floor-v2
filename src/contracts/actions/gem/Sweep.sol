// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '../../../interfaces/actions/Action.sol';


/// ..
error UnableToSweepGem();

/**
 * @notice Allows sweeping from Gem.xyz to facilitate the purchasing and immediate
 * staking of ERC721s.
 *
 * @author Twade
 */

contract SweepAndStake is IAction, Ownable, Pausable {

    /// Internal store of whitelisted addresses
    mapping (address => bool) internal whitelisted;

    /// @notice Emitted when ..
    event Sweep(uint ethAmount);

    /**
     * Store our required information to action a swap.
     *
     * @param asset Address of the token being liquidated
     * @param vaultId NFTX vault ID
     * @param tokenIds Array of token IDs owned by the {Treasury} to be liquidated
     * @param minEthOut The minimum amount of ETH to receive, otherwise the transaction
     * will be reverted to prevent front-running
     * @param path The generated exchange path
     */
    struct ActionRequest {
        address target;
        bytes txData;
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint spent) {
        // Unpack the request bytes data into individual variables, as mapping it directly
        // to the struct is buggy due to memory -> storage array mapping.
        (address target, bytes memory txData) = abi.decode(_request, (address, bytes));

        // Ensure our address is whitelisted
        require(whitelisted[target], 'Call target is not whitelisted');

        // Sweeps from GemSwap. This scares me.
        (bool success,) = target.call(txData);
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
     *
     * @param _whitelist Address to be updated
     * @param _value Whether the address is to be whitelisted or blocked
     */

    function whitelistAddress(address _whitelist, bool _value) external onlyOwner {
        whitelisted[_whitelist] = _value;
    }

}
