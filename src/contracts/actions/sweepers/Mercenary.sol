// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IMercenarySweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {IFloorWars} from '@floor-interfaces/voting/FloorWars.sol';

/**
 *
 *
 * @dev This sweeper makes the assumption that only one collection and amount will
 * be passed through as this is used for the Collection Addition War which, at time
 * of writing, should only allow for a singular winner to be crowned.
 */
contract MercenarySweeper is IMercenarySweeper {

    /// ..
    IFloorWars public immutable floorWars;

    /**
     * ..
     */
    constructor (address _floorWars) {
        floorWars = IFloorWars(_floorWars);
    }

    /**
     * ..
     */
    function execute(uint warIndex, uint amount) external payable override returns (uint) {
        // Keep track of the amount spent
        uint startBalance = address(this).balance;

        // Find the token IDs that we intend to buy with
        uint[] memory tokenIds = floorWars.getErc721TokenIds(warIndex, amount);

        // Check amount to spend is over 0
        if (tokenIds.length > 0) {
            // Exercise the specified token IDs
            floorWars.exerciseCollectionERC721s{value: msg.value}(warIndex, tokenIds);
        }

        // Return the amount spent as a string
        return startBalance - address(this).balance;
    }

}
