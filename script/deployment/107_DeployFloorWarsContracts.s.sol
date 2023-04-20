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
        address vaultFactory = requireDeployment('VaultFactory');
        address veFloorStaking = requireDeployment('VeFloorStaking');
        address voteStaking = requireDeployment('VoteStaking');

        NewCollectionWars newCollectionWars = new NewCollectionWars(
            authorityControl,   // address _authority
            floorNft,           // address _floorNft
            treasury,           // address _treasury
            voteStaking         // address _veFloor
        );

        SweepWars sweepWars = new SweepWars(
            collectionRegistry,     // address _collectionRegistry
            vaultFactory,           // address _vaultFactory
            veFloorStaking,         // address _veFloor
            authorityControl,       // address _authority
            treasury                // address _treasury
        );

        storeDeployment('NewCollectionWars', address(newCollectionWars));
        storeDeployment('SweepWars', address(sweepWars));

    }

}
