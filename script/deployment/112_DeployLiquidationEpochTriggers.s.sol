// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {LiquidateNegativeCollectionManualTrigger} from '@floor/triggers/LiquidateNegativeCollectionManual.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our liquidation epoch trigger.
 */
contract DeployLiquidationEpochTriggers is DeploymentScript {
    function run() external deployer {
        // Register our epoch manager so we can make calls against it
        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

        // Load and reference our live authority contracts
        IAuthorityControl authorityControl = IAuthorityControl(requireDeployment('AuthorityControl'));
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        // Load our required contract addresses
        address strategyFactory = requireDeployment('StrategyFactory');
        address sweepWars = requireDeployment('SweepWars');

        // Register our epoch end trigger that stores our liquidation
        LiquidateNegativeCollectionManualTrigger liquidateNegativeCollectionManualTrigger = new LiquidateNegativeCollectionManualTrigger(
            sweepWars,
            strategyFactory
        );

        // Register our epoch trigger
        epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionManualTrigger), true);

        // Set our epoch manager
        liquidateNegativeCollectionManualTrigger.setEpochManager(address(epochManager));

        // Finally, store our trigger
        storeDeployment('LiquidateNegativeCollectionManualTrigger', address(liquidateNegativeCollectionManualTrigger));
    }
}
