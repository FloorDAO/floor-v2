// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 */
contract ExecuteSweep is DeploymentScript {

    function run() external deployer {

        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Action a SudoSwap Sweep
        treasury.sweepEpoch(1, requireDeployment('SweeperRouter'), '', 0);

    }

}
