// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our floor wars contracts.
 */
contract DeployFloorWarsContracts is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        address authorityControl = requireDeployment('AuthorityControl');
        address collectionRegistry = requireDeployment('CollectionRegistry');
        address floorNft = requireDeployment('FloorNft');
        address treasury = requireDeployment('Treasury');
        address strategyFactory = requireDeployment('StrategyFactory');
        address veFloorStaking = requireDeployment('VeFloorStaking');

        NewCollectionWars newCollectionWars = new NewCollectionWars(
            authorityControl,   // address _authority
            veFloorStaking      // address _veFloor
        );

        SweepWars sweepWars = new SweepWars(
            collectionRegistry,     // address _collectionRegistry
            strategyFactory,        // address _strategyFactory
            veFloorStaking,         // address _veFloor
            authorityControl,       // address _authority
            treasury                // address _treasury
        );

        storeDeployment('NewCollectionWars', address(newCollectionWars));
        storeDeployment('SweepWars', address(sweepWars));
    }
}
