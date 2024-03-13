// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {CharmStrategy} from '@floor/strategies/CharmStrategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract DeployCharmStrategy is DeploymentScript {

    function run() external deployer {

        // Deploy strategy
        CharmStrategy charmStrategy = new CharmStrategy();

        // Deploy our strategy registry
        StrategyRegistry strategyRegistry = StrategyRegistry(requireDeployment('StrategyRegistry'));
        strategyRegistry.approveStrategy(address(charmStrategy), true);

        // Store our strategies deployment address
        storeDeployment('CharmStrategy', address(charmStrategy));

    }

}
