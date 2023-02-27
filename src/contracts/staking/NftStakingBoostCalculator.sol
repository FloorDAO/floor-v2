// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ABDKMath64x64} from '@floor/forks/ABDKMath64x64.sol';

import {INftStakingBoostCalculator} from '@floor-interfaces/staking/NftStakingBoostCalculator.sol';


/**
 * ..
 */
contract NftStakingBoostCalculator is INftStakingBoostCalculator {

    /**
     * ..
     */
    function calculate(uint sweepPower, uint sweepTotal, uint sweepModifier) external pure returns (uint boost_) {
        // If we don't have any power, then our multiplier will just be 1
        if (sweepPower == 0) {
            return 1e9;
        }

        // Determine our logarithm base. When we only have one token, we get a zero result which
        // would lead to a zero division error. To avoid this, we ensure that we set a minimum
        // value of 1.
        uint _voteModifier = sweepModifier;
        if (sweepTotal == 1) {
            _voteModifier = (sweepModifier * 125) / 100;
            sweepTotal = 2;
        }

        // Apply our modifiers to our calculations to determine our final multiplier
        boost_ = (
            (
                (
                    ABDKMath64x64.toUInt(
                        ABDKMath64x64.ln(ABDKMath64x64.fromUInt(sweepPower)) * 1e6
                    ) * 1e9
                )
                /
                (
                    ABDKMath64x64.toUInt(
                        ABDKMath64x64.ln(ABDKMath64x64.fromUInt(sweepTotal)) * 1e6
                    )
                )
            ) * (
                (
                    ABDKMath64x64.toUInt(
                        ABDKMath64x64.sqrt(ABDKMath64x64.fromUInt(sweepTotal)) * 1e9
                    )
                ) - 1e9
            )
        ) / _voteModifier;

        if (boost_ < 1e9) {
            boost_ = 1e9;
        }

    }

}
