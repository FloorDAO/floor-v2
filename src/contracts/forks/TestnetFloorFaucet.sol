// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFLOOR} from '@floor-interfaces/tokens/Floor.sol';


/**
 * Provides the ability for external users to mint Floor to their wallet every set
 * interval. This will help promote testing on the testnet platforms.
 *
 * This should _never_ be deployed on mainnet.
 *
 * @dev This contract must have `FLOOR_MANAGER` permissions against the {FLOOR} token.
 */
contract TestnetFloorFaucet {

    /// Interface for the deployed {FLOOR} token
    IFLOOR public immutable floorToken;

    /// The number of Floor tokens to drip to the caller
    uint public constant DRIP_AMOUNT = 1000 ether;

    /// The cooldown period between a user re-calling the faucet drip
    uint public constant COOLDOWN = 10 minutes;

    /// Tracks the last time each address dripped the Faucet
    mapping (address => uint) public lastDrip;

    /**
     * Register our {FLOOR} token address.
     */
    constructor(address _floorToken) {
        floorToken = IFLOOR(_floorToken);
    }

    /**
     * Allows for a set amount of {FLOOR} token to be minted to the caller when called.
     */
    function drip() public {
        // Ensure that the user has not called drip within the cooldown period
        require(lastDrip[msg.sender] + COOLDOWN <= block.timestamp, 'Cooldown period has not passed');

        // Update the last drip time for the user
        lastDrip[msg.sender] = block.timestamp;

        // Mint the {FLOOR} token to the caller
        floorToken.mint(msg.sender, DRIP_AMOUNT);
    }
}
