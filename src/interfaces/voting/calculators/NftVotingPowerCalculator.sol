// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INftVotingPowerCalculator {
    function calculate(uint warIndex, address collection, uint spotPrice, uint exercisePercent) external pure returns (uint);
}
