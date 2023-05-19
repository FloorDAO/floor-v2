// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftStakingBoostCalculator {
    function calculate(uint sweepPower, uint sweepTotal, uint sweepModifier) external view returns (uint boost_);
}
