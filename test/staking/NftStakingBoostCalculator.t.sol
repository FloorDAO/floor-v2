// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {NftStakingBoostCalculator} from '@floor/staking/calculators/NftStakingBoostCalculator.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NftStakingBoostCalculatorTest is FloorTest {

    // Internal contract references
    NftStakingBoostCalculator calculator;

    constructor() {
        // Set up our boost calculator
        calculator = new NftStakingBoostCalculator();
    }

    function test_CanCalculate() external {
        assertEq(calculator.calculate(0, 0, 4000000000), 1000000000);
        assertEq(calculator.calculate(434, 15, 4000000000), 1610730439);
        assertEq(calculator.calculate(231, 7, 4000000000), 1150729596);
        assertEq(calculator.calculate(7839, 1, 4000000000), 1071691143);
        assertEq(calculator.calculate(10452, 1, 4000000000), 1106073976);
        assertEq(calculator.calculate(12566, 231, 4000000000), 6156172431);
    }

    function test_CanCalculateBoundaries() external {
        // Test our min values
        calculator.calculate(0, 0, 0);

        // Test our max values
        calculator.calculate(type(uint56).max, type(uint56).max, type(uint56).max);

        // If we go over uint56 across the variables then we get an exception
        vm.expectRevert();
        calculator.calculate(type(uint64).max, type(uint64).max, type(uint64).max);
    }

}
