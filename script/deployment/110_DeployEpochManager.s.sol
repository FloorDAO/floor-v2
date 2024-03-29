// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
 */
contract DeployEpochManager is DeploymentScript {
    function run() external deployer {
        // Load our required contract addresses
        address newCollectionWars = requireDeployment('NewCollectionWars');
        address payable treasury = requireDeployment('Treasury');
        address veFloorStaking = requireDeployment('VeFloorStaking');

        // Deploy our epoch manager
        EpochManager epochManager = new EpochManager();

        // Set our contracts against the new epoch manager
        epochManager.setContracts(newCollectionWars, address(0));

        // Assign our epoch manager to our existing contracts
        NewCollectionWars(newCollectionWars).setEpochManager(address(epochManager));
        Treasury(treasury).setEpochManager(address(epochManager));
        VeFloorStaking(veFloorStaking).setEpochManager(address(epochManager));

        // Finally, we can save our epoch manager contract address
        storeDeployment('EpochManager', address(epochManager));
    }
}
