// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import '@openzeppelin/contracts/utils/Strings.sol';

import '../../src/contracts/options/Option.sol';
import '../../src/contracts/options/OptionDistributionWeightingCalculator.sol';
import '../../src/contracts/options/OptionExchange.sol';

/**
 * Outputs a seeded distribution of option weightings. This can be used for
 * testing a new strategy to determine its output before deploying to a
 * production level system.
 */
contract VisualiseOptionWeighting is Script {
    uint SEED_1 = 9876543210;
    uint SEED_2 = 1234567890;

    function run() public {
        OptionDistributionWeightingCalculator weighting = new OptionDistributionWeightingCalculator(
            abi.encode(_distribution())
        );

        // Map our share allocation, which will always be < 100
        uint allocatedAmount;

        // Whilst we have remaining allocation of the pool amount assigned, create options
        uint i;
        while (allocatedAmount < 100) {
            unchecked {
                ++i;
            }

            // Get our weighted share allocation. If it is equal to 0, then
            // we set it to 1 as the minimum value.
            uint share = weighting.getShare(SEED_1 / 10000 * i);

            // Get our discount allocation
            uint discount = weighting.getDiscount(SEED_2 / 10000 * i);

            // If our share allocation puts us over the total pool amount then
            // we just need provide the user the maximum remaining.
            if (allocatedAmount + share > 100) {
                share = 100 - allocatedAmount;
            }

            console.log(string(abi.encodePacked('Share: ', Strings.toString(share), '% :: Discount: ', Strings.toString(discount), '%')));

            // Add our share to the allocated amount
            allocatedAmount += share;
        }
    }

    function _distribution() internal pure returns (uint[] memory) {
        // Set our weighting ladder
        uint[] memory _weights = new uint[](21);
        _weights[0] = 1453;
        _weights[1] = 2758;
        _weights[2] = 2653;
        _weights[3] = 2424;
        _weights[4] = 2293;
        _weights[5] = 1919;
        _weights[6] = 1725;
        _weights[7] = 1394;
        _weights[8] = 1179;
        _weights[9] = 887;
        _weights[10] = 700;
        _weights[11] = 524;
        _weights[12] = 370;
        _weights[13] = 270;
        _weights[14] = 191;
        _weights[15] = 122;
        _weights[16] = 100;
        _weights[17] = 51;
        _weights[18] = 29;
        _weights[19] = 18;
        _weights[20] = 12;

        return _weights;
    }
}
