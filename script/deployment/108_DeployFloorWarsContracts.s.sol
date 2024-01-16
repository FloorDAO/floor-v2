// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
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

        // Update our vefloor staking contract references
        VeFloorStaking(veFloorStaking).setVotingContracts(address(newCollectionWars), address(sweepWars));
        VeFloorStaking(veFloorStaking).setMaxLossRatio(90_0000000); // 90%

        storeDeployment('NewCollectionWars', address(newCollectionWars));
        storeDeployment('SweepWars', address(sweepWars));
    }
}
