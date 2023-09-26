// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 */
contract SweepEpoch is DeploymentScript {

    function run() external deployer {

        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        epochManager.endEpoch();

        Treasury treasury = Treasury(requireDeployment('Treasury'));
        treasury.sweepEpoch(0, requireDeployment('ManualSweeper'), '', 0);

        epochManager.endEpoch();
        treasury.sweepEpoch(1, requireDeployment('ManualSweeper'), '', 0);
    }


}
