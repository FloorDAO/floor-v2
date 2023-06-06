// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INftVotingPowerCalculator} from '@floor-interfaces/voting/calculators/NftVotingPowerCalculator.sol';


/**
 * Calculates the voting power applied from a created option, factoring in the spot
 * price and exercise percentage.
 *
 * The formula for this is documented against the `calculate` function.
 */
contract NewCollectionNftOptionVotingPowerCalculator is INftVotingPowerCalculator {
    /**
     * Performs the calculation to return the vote power given from an
     * exercisable option.
     */
    function calculate(uint /* warIndex */, address /* collection */, uint spotPrice, uint exercisePercent) external pure returns (uint) {
        // If the user has matched our spot price, then we return full value
        if (exercisePercent == 100) {
            return spotPrice;
        }

        // The user cannot place an exercise price above the spot price that has been set. This
        // information should be validated internally before this function is called to prevent
        // this from happening.
        if (exercisePercent > 100) {
            return 0;
        }

        // Otherwise, if the user has set a lower spot price, then the voting power will be
        // increased as they are offering the NFT at a discount.
        unchecked {
            return spotPrice + ((spotPrice * (100 - exercisePercent)) / 100);
        }
    }
}
