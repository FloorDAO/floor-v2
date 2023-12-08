// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SweepWars} from '@floor/voting/SweepWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Updates the sample size in the sweep wars.
 */
contract SetSampleSize is DeploymentScript {

    function run() external deployer {

        // Load our required contract addresses
        SweepWars sweepWars = SweepWars(requireDeployment('SweepWars'));

        // Set our sample size
        sweepWars.setSampleSize(1);
    }
}
