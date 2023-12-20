// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract HarvestStrategy is DeploymentScript {

    function run() external deployer {

        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        strategyFactory.harvest(8);

    }

}
