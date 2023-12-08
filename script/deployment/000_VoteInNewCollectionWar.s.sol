// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 *
 */
contract VoteInNewCollectionWar is DeploymentScript {

    address collectionOne   = 0x3d7E741B5E806303ADbE0706c827d3AcF0696516;
    address collectionTwo   = 0xa807e2a221C6dAAFE1b4A3ED2dA5E8A53fDAf6BE;

    EpochManager epochManager;
    NewCollectionWars newCollectionWars;

    function run() external deployer {

        // Deploy our new {NewCollectionWars} contract
        epochManager = EpochManager(requireDeployment('EpochManager'));
        newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        address[] memory collections = new address[](2);
        collections[0] = collectionOne;
        collections[1] = collectionTwo;

        bool[] memory isErc1155 = new bool[](2);
        isErc1155[0] = false;
        isErc1155[1] = false;

        uint[] memory floorPrices = new uint[](2);
        floorPrices[0] = 1 ether;
        floorPrices[1] = 1 ether;

        // Create a new collection war for the next epoch
        newCollectionWars.createFloorWar(epochManager.currentEpoch() + 1, collections, isErc1155, floorPrices);

    }

}
