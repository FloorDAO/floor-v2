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
        address distributedRevenueStakingStrategy = requireDeployment('DistributedRevenueStakingStrategy');
        address strategyFactory = requireDeployment('StrategyFactory');
        address sweepWars = requireDeployment('SweepWars');

        // Register a {DistributedRevenueStakingStrategy} strategy so that we can deploy a
        // {liquidateNegativeCollectionManualTrigger}.
        (, address _strategy) = StrategyFactory(strategyFactory).deployStrategy(
            bytes32('Liquidation Pool'),
            distributedRevenueStakingStrategy,
            abi.encode(WETH, 10 ether, address(epochManager)),
            0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6 // The collection is not important, it just needs to be approved
        );

        // Register our epoch end trigger that stores our liquidation
        LiquidateNegativeCollectionManualTrigger liquidateNegativeCollectionManualTrigger = new LiquidateNegativeCollectionManualTrigger(
            sweepWars,
            strategyFactory,
            _strategy
        );

        // Check if we have an existing liquidation trigger and unset it if present
        address existingLiquidationManualTrigger = getDeployment('LiquidateNegativeCollectionManualTrigger');
        if (existingLiquidationManualTrigger != address(0)) {
            epochManager.setEpochEndTrigger(existingLiquidationManualTrigger, false);
            authorityRegistry.revokeRole(authorityControl.STRATEGY_MANAGER(), existingLiquidationManualTrigger);
        }

        // Register our epoch trigger
        epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionManualTrigger), true);

        // The trigger needs the `STRATEGY_MANAGER` role
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(liquidateNegativeCollectionManualTrigger));

        // Set our epoch manager
        liquidateNegativeCollectionManualTrigger.setEpochManager(address(epochManager));

        // Finally, store our trigger
        storeDeployment('LiquidateNegativeCollectionManualTrigger', address(liquidateNegativeCollectionManualTrigger));
    }
}
