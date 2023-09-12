// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our epoch triggers.
 */
contract DeployEpochTriggers is DeploymentScript {
    function run() external deployer {
        // Register our epoch manager so we can make calls against it
        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

        // Load our required contract addresses
        address newCollectionWars = requireDeployment('NewCollectionWars');
        address pricingExecutor = requireDeployment('UniswapV3PricingExecutor');
        address strategyFactory = requireDeployment('StrategyFactory');
        address sweepWars = requireDeployment('SweepWars');
        address payable treasury = requireDeployment('Treasury');

        // Deploy our triggers
        RegisterSweepTrigger registerSweep =
            new RegisterSweepTrigger(newCollectionWars, pricingExecutor, strategyFactory, treasury, sweepWars);
        StoreEpochCollectionVotesTrigger storeEpochVotes = new StoreEpochCollectionVotesTrigger(sweepWars);

        // Register our epoch triggers
        epochManager.setEpochEndTrigger(address(registerSweep), true);
        epochManager.setEpochEndTrigger(address(storeEpochVotes), true);

        // Set our epoch manager
        registerSweep.setEpochManager(address(epochManager));
        storeEpochVotes.setEpochManager(address(epochManager));

        // Finally, store our triggers
        storeDeployment('RegisterSweepTrigger', address(registerSweep));
        storeDeployment('StoreEpochCollectionVotesTrigger', address(storeEpochVotes));
    }
}
