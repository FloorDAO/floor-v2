// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract GetActiveEpochTriggers is DeploymentScript {

    function run() external deployer {

        // Load our epoch manager
        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        address[] memory epochEndTriggers = epochManager.epochEndTriggers();

        // Loop through active triggers
        for (uint i; i < epochEndTriggers.length; ++i) {
            console.log(epochEndTriggers[i]);
        }
    }

}
