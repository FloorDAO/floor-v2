// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../interfaces/options/OptionDistributionCalculator.sol';


/**
 * Our Weighting calculator allows us to set a predefined ladder of weights that
 * map to an allocation amount. This allows us to set a gas optimised method of
 * allocation traversal.
 */
contract OptionDistributionWeightingCalculator is IOptionDistributionCalculator {

    /// Stores the total value of all weightings. We use this to
    /// offset our seed to be within an expected range.
    uint public immutable sum;

    /// Stores the length of our weights array to save gas in loops
    uint public immutable length;

    /// Stores our allocation : weight array
    uint[] public weights;

    /**
     * Accepts a bytes-encoded array of unsigned integers. We then store static
     * calculations to reduce gas on future calls.
     */
    constructor (bytes memory initData) {
        (weights) = abi.decode(initData, (uint[]));
        length = weights.length;

        uint total;
        for (uint16 i; i < length;) {
            total += weights[i];
            unchecked { ++i; }
        }
        sum = total;
    }

    /**
     * Get the share allocation based on the seed. If we generate a 0 share then we
     * set it to 1 as a minimum threshold.
     */
    function getShare(uint seed) external virtual override returns (uint share) {
        share = _get(seed);
        if (share == 0) { share = 1; }
    }

    /**
     * Get the discount allocation based on the seed.
     */
    function getDiscount(uint seed) external virtual override returns (uint) {
        return _get(seed);
    }

    /**
     * We use our seed to find where our seed falls in the weighted ladder. The
     * key of our weights array maps to the allocation granted, whilst the value
     */
    function _get(uint seed) internal view returns (uint i) {
        // Find the modulus of the provided seed
        int ticker = int(seed % sum);

        // Iterate over our weighting ladder
        for (i; i < length;) {
            // Reduce the amount from our seed tick and if it falls below
            // zero-value then we have found the boundary of our seed.
            ticker -= int(weights[i]);
            if (ticker <= 0) {
                return i;
            }

            unchecked { ++i; }
        }
    }

}
