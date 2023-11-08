// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our treasury actions.
 */
contract ApproveSweepers is DeploymentScript {

    function run() external deployer {
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Load our sweepers and approve for sweeping
        treasury.approveSweeper(requireDeployment('ManualSweeper'), true);
        treasury.approveSweeper(requireDeployment('GemSweeper'), true);
    }

}
