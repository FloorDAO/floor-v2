// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {CannotSetNullAddress, InsufficientAmount} from '@floor/utils/Errors.sol';

import {IgFLOOR} from '@floor-interfaces/legacy/IgFLOOR.sol';
import {IMigrateFloorToken} from '@floor-interfaces/migrations/MigrateFloorToken.sol';

/// If there are no tokens available for the recipient
error NoTokensAvailableToMigrate();

/**
 * Burns FLOOR v1 tokens for FLOOR v2 tokens. We have a list of the defined
 * V1 tokens in our test suites that should be accept. These include a, g and
 * s floor variants.
 *
 * This should provide a 1:1 V1 burn -> V2 mint of tokens.
 *
 * The balance of all tokens will be attempted to be migrated, so 4 full approvals
 * should be made prior to calling this contract function.
 */
contract MigrateFloorToken is IMigrateFloorToken {
    using SafeERC20 for IERC20;

    /// List of FLOOR V1 token contract addresses on mainnet
    address[] private MIGRATED_TOKENS = [
        0xf59257E961883636290411c11ec5Ae622d19455e, // Floor
        0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA, // aFloor
        0xb1Cc59Fc717b8D4783D41F952725177298B5619d, // gFloor
        0x164AFe96912099543BC2c48bb9358a095Db8e784 // sFloor
    ];

    /// Contract address of new FLOOR V2 token
    address public immutable newFloor;

    /// Emitted when tokens have been migrated to a user
    event FloorMigrated(address caller, uint amount);

    /**
     * Stores the deployed V2 FLOOR token contract address.
     *
     * @param _newFloor Address of our deployed FLOOR V2 token
     */
    constructor(address _newFloor) {
        if (_newFloor == address(0)) revert CannotSetNullAddress();
        newFloor = _newFloor;
    }

    /**
     * Iterates through existing V1 FLOOR tokens and mints them into FLOOR V2 tokens. The existing
     * V1 tokens aren't burnt, but are just left in the existing wallet.
     *
     * @dev For the gFloor token, we need to update the decimal accuracy from 9 to 18.
     */
    function upgradeFloorToken() external override {
        // Keep a running total of allocated tokens
        uint floorAllocation;
        uint tokenBalance;
        IERC20 token;

        // Loop through the tokens
        for (uint8 i; i < MIGRATED_TOKENS.length;) {
            token = IERC20(MIGRATED_TOKENS[i]);

            // Get the user's balance of the token
            tokenBalance = token.balanceOf(msg.sender);

            // Ensure that there is a balance to transfer
            if (tokenBalance > 0) {
                // Transfer all tokens to the contract
                token.safeTransferFrom(msg.sender, address(this), tokenBalance);

                // If we have a gFLOOR token, then we need to find the underlying FLOOR that
                // is staked and mint that for the user.
                if (address(token) == 0xb1Cc59Fc717b8D4783D41F952725177298B5619d) {
                    tokenBalance = IgFLOOR(address(token)).balanceFrom(tokenBalance);
                }

                // Increment our `floorAllocation` based on the token balance of the user. gFloor
                // is the only 18 decimal token that we migrate, but this is converted to Floor just
                // above this. So this means that at this point in the logic, all tokens are 9
                // decimal so we need some explicit logic to cater for this.
                floorAllocation += tokenBalance * (10 ** 9);
            }

            unchecked {
                ++i;
            }
        }

        // Assert that we have tokens to mint, otherwise we revert the tx
        if (floorAllocation == 0) {
            revert NoTokensAvailableToMigrate();
        }

        // Mint our FLOOR tokens to the sender
        FLOOR(newFloor).mint(msg.sender, floorAllocation);
        emit FloorMigrated(msg.sender, floorAllocation);
    }
}
