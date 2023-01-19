// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../tokens/Floor.sol';
import '../../interfaces/migrations/MigrateFloorToken.sol';

/**
 * Burns FLOOR v1 tokens for FLOOR v2 tokens. We have a list of the defined
 * V1 tokens in our test suites that should be accept. These include a, g and
 * s floor variants.
 *
 * This should provide a 1:1 V1 burn > V2 mint of tokens.
 *
 * The balance of all tokens will be attempted to be migrated, so 4 full approvals
 * should be made prior to calling this contract function.
 */
contract MigrateFloorToken is IMigrateFloorToken {
    address[] private MIGRATED_TOKENS = [
        0xf59257E961883636290411c11ec5Ae622d19455e, // Floor
        0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA, // aFloor
        0xb1Cc59Fc717b8D4783D41F952725177298B5619d, // gFloor
        0x164AFe96912099543BC2c48bb9358a095Db8e784 // sFloor
    ];

    event FloorMigrated(address caller, uint amount);

    address public immutable newFloor;

    constructor(address _newFloor) {
        newFloor = _newFloor;
    }

    function mintTokens(uint _amount) external override {
        FLOOR(newFloor).mint(address(this), _amount);
    }

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

            // Transfer the token into our contract
            if (tokenBalance > 0 && token.transferFrom(msg.sender, address(this), tokenBalance)) {
                // Add the amount transferred to a running tally. gFloor is the only 18
                // decimal token that we migrate, but the others are 9 decimal so we need
                // some explicit logic to cater for this.
                if (address(token) != 0xb1Cc59Fc717b8D4783D41F952725177298B5619d) {
                    tokenBalance *= (10 ** 9);
                }

                floorAllocation += tokenBalance;
            }

            unchecked {
                ++i;
            }
        }

        require(floorAllocation > 0, 'No tokens available to migrate');

        // Mint our FLOOR tokens to the sender
        FLOOR(newFloor).mint(msg.sender, floorAllocation);
        emit FloorMigrated(msg.sender, floorAllocation);
    }
}
