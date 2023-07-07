// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
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
        address veFloorStaking = requireDeployment('VeFloorStaking');

        // Deploy our triggers
        RegisterSweepTrigger registerSweep =
            new RegisterSweepTrigger(newCollectionWars, pricingExecutor, strategyFactory, treasury, veFloorStaking);
        StoreEpochCollectionVotesTrigger storeEpochVotes = new StoreEpochCollectionVotesTrigger(sweepWars);

        // Register our epoch triggers
        epochManager.setEpochEndTrigger(address(registerSweep), true);
        epochManager.setEpochEndTrigger(address(storeEpochVotes), true);

        // Finally, store our triggers
        storeDeployment('RegisterSweepTrigger', address(registerSweep));
        storeDeployment('StoreEpochCollectionVotesTrigger', address(storeEpochVotes));
    }
}
