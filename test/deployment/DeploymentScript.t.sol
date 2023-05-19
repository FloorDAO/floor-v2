// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

import {FloorTest} from '../utilities/Environments.sol';

/**
 * ..
 */
contract DeploymentScriptTest is DeploymentScript, FloorTest {
    function test_CanRequireDeployment() external {
        // Cannot access unknown value
        vm.expectRevert('Contract has not been deployed');
        requireDeployment('Testing');

        // Can add initial value
        storeDeployment('Testing', address(1));
        assertEq(requireDeployment('Testing'), address(1));

        // Can add a new value
        storeDeployment('TestingAgain', address(2));
        assertEq(requireDeployment('Testing'), address(1));
        assertEq(requireDeployment('TestingAgain'), address(2));

        // Cannot add zero address
        vm.expectRevert('Cannot store zero address');
        storeDeployment('TestingFinal', address(0));

        // Can update value
        storeDeployment('Testing', address(3));
        assertEq(requireDeployment('Testing'), address(3));
        assertEq(requireDeployment('TestingAgain'), address(2));
    }
}
