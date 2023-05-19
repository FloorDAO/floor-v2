// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
 */
contract DeployCoreContracts is DeploymentScript {
    function run() external deployer {
        // Load our required contract addresses
        address collectionRegistry = requireDeployment('CollectionRegistry');
        address newCollectionWars = requireDeployment('NewCollectionWars');
        address pricingExecutor = requireDeployment('PricingExecutor');
        address sweepWars = requireDeployment('SweepWars');
        address payable treasury = requireDeployment('Treasury');
        address vaultFactory = requireDeployment('VaultFactory');
        address veFloorStaking = requireDeployment('VeFloorStaking');
        address voteContract = requireDeployment('VoteContract');

        // Deploy our epoch manager
        EpochManager epochManager = new EpochManager();

        // Set our contracts against the new epoch manager
        epochManager.setContracts(
            collectionRegistry,
            newCollectionWars,
            pricingExecutor,
            treasury,
            vaultFactory,
            voteContract,
            address(0) // voteMarket
        );

        // Assign our epoch manager to our existing contracts
        NewCollectionWars(newCollectionWars).setEpochManager(address(epochManager));
        SweepWars(sweepWars).setEpochManager(address(epochManager));
        Treasury(treasury).setEpochManager(address(epochManager));
        VeFloorStaking(veFloorStaking).setEpochManager(address(epochManager));

        // Finally, we can save our epoch manager contract address
        storeDeployment('EpochManager', address(epochManager));
    }
}
