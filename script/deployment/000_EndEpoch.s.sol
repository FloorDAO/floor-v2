// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Ends the current epoch.
 */
contract EndEpoch is DeploymentScript {

    function run() external deployer {

        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        epochManager.endEpoch();

    }

}
