// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ILegacyTreasury} from '@floor-interfaces/legacy/Treasury.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/**
 * This allows for tokens from the old {Treasury} to be migrated to the new {Treasury}.
 *
 * The existing {Treasury} only holds ERC20 tokens, so the migration pattern is relatively
 * very simple.
 *
 * @dev This contract needs `permissions[STATUS.ALLOCATOR][msg.sender]` permissions in order
 * to make these migrations. This role must be assigned to this contract after deployment.
 */
contract MigrateTreasury is Ownable {
    /// Contract addresses of our new and old {Treasury} contracts
    ILegacyTreasury public immutable oldTreasury;
    ITreasury public immutable newTreasury;

    /// Emitted when tokens have been migrated to the new Treasury
    event TokenMigrated(address token, uint received, uint sent);

    /**
     * Stores our immutable {Treasury} addresses.
     *
     * @param _oldTreasury Address of our old {Treasury}
     * @param _newTreasury Address of our new, V2 {Treasury}
     */
    constructor(address _oldTreasury, address _newTreasury) {
        oldTreasury = ILegacyTreasury(_oldTreasury);
        newTreasury = ITreasury(_newTreasury);
    }

    /**
     * Iterates over specified tokens to extract from the old {Treasury} and send to the
     * new {Treasury}. This will always process the full balances of the token, so an amount
     * is not required to be specified.
     */
    function migrate(address[] memory tokens) external onlyOwner {
        // Define variables outside the loop for gas saves
        uint received;
        uint sent;
        IERC20 token;

        // Iterate over our tokens that are passed in
        uint length = tokens.length;
        for (uint i; i < length;) {
            // Map our token to an IERC20
            token = IERC20(tokens[i]);

            // Get the amount of balance currently held by the {Treasury} and ensure
            // that it isn't a zero amount.
            received = token.balanceOf(address(oldTreasury));
            if (received == 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            // Process our withdrawal from the old {Treasury} for the token
            oldTreasury.allocatorManage(address(token), uint(received));

            // Get the amount of the token now held by this migration contract and approve
            // it against our new {Treasury}.
            sent = token.balanceOf(address(this));
            token.approve(address(newTreasury), sent);

            // Transfer the token to our new {Treasury}
            newTreasury.depositERC20(address(token), sent);

            // Fire an event to show the amount of token received and sent
            emit TokenMigrated(address(token), received, sent);

            unchecked {
                ++i;
            }
        }
    }
}
