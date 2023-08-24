// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {LiquidateNegativeCollectionTrigger} from '@floor/triggers/LiquidateNegativeCollection.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our liquidation epoch trigger.
 */
contract DeployLiquidationEpochTriggers is DeploymentScript {
    function run() external deployer {
        // Register our epoch manager so we can make calls against it
        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

        // Load our required contract addresses
        address distributedRevenueStakingStrategy = requireDeployment('DistributedRevenueStakingStrategy');
        address strategyFactory = requireDeployment('StrategyFactory');
        address sweepWars = requireDeployment('SweepWars');

        // Register a {DistributedRevenueStakingStrategy} strategy so that we can deploy a
        // {LiquidateNegativeCollectionTrigger}.
        (, address _strategy) = StrategyFactory(strategyFactory).deployStrategy(
            bytes32('Liquidation Pool'),
            distributedRevenueStakingStrategy,
            abi.encode(WETH, 10 ether, address(epochManager)),
            0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB // The collection is not important, it just needs to be approved
        );

        // Register our epoch end trigger that stores our liquidation
        LiquidateNegativeCollectionTrigger liquidateNegativeCollectionTrigger = new LiquidateNegativeCollectionTrigger(
            sweepWars,
            strategyFactory,
            _strategy,
            0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD, // Uniswap Universal Router
            WETH
        );

        // Register our epoch trigger
        epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionTrigger), true);

        // Finally, store our trigger
        storeDeployment('LiquidateNegativeCollectionTrigger', address(liquidateNegativeCollectionTrigger));

        // Set our epoch manager
        liquidateNegativeCollectionTrigger.setEpochManager(address(epochManager));
    }
}
