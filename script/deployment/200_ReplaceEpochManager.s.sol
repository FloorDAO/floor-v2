// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

interface IEpochManaged {
    function setEpochManager(address) external;
}


/**
 * Deploys our treasury actions.
 */
contract ReplaceEpochManager is DeploymentScript {
    function run() external deployer {

        // Load our required contract addresses
        address newCollectionWars = requireDeployment('NewCollectionWars');
        address payable treasury = requireDeployment('Treasury');
        address veFloorStaking = requireDeployment('VeFloorStaking');
        address registerSweep = requireDeployment('RegisterSweepTrigger');
        address storeEpochVotes = requireDeployment('StoreEpochCollectionVotesTrigger');
        address liquidateNegativeCollectionTrigger = requireDeployment('LiquidateNegativeCollectionTrigger');

        // Deploy our epoch manager
        EpochManager epochManager = new EpochManager();

        // Set our contracts against the new epoch manager
        epochManager.setContracts(newCollectionWars, address(0));

        // Assign our epoch manager to our existing contracts
        IEpochManaged(newCollectionWars).setEpochManager(address(epochManager));
        IEpochManaged(treasury).setEpochManager(address(epochManager));
        IEpochManaged(veFloorStaking).setEpochManager(address(epochManager));
        IEpochManaged(registerSweep).setEpochManager(address(epochManager));
        IEpochManaged(storeEpochVotes).setEpochManager(address(epochManager));
        IEpochManaged(liquidateNegativeCollectionTrigger).setEpochManager(address(epochManager));

        // Register our epoch triggers
        epochManager.setEpochEndTrigger(registerSweep, true);
        epochManager.setEpochEndTrigger(storeEpochVotes, true);
        epochManager.setEpochEndTrigger(liquidateNegativeCollectionTrigger, true);

        // Finally, we can save our epoch manager contract address
        storeDeployment('EpochManager', address(epochManager));
    }
}
