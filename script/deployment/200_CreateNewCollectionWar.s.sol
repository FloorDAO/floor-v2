// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 *
 */
contract CreateNewCollectionWar is DeploymentScript {

    EpochManager epochManager;
    NewCollectionWars newCollectionWars;

    function run() external deployer {

        // Deploy our new {NewCollectionWars} contract
        epochManager = EpochManager(requireDeployment('EpochManager'));
        newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        address[] memory collections = new address[](5);
        collections[0] = 0x7b2a53DAF97Ea7aa31B646e079C4772b6198aE9B;
        collections[1] = 0xa807e2a221C6dAAFE1b4A3ED2dA5E8A53fDAf6BE;
        collections[2] = 0x3d7E741B5E806303ADbE0706c827d3AcF0696516;
        collections[3] = 0x27F2957b2205f417f6a4761Eac9E0920C6c9c3dc;
        collections[4] = 0xBD9D18DC11140913cA13585dAdc770C1a4b41569;

        bool[] memory isErc1155 = new bool[](5);
        isErc1155[0] = false;
        isErc1155[1] = false;
        isErc1155[2] = false;
        isErc1155[3] = false;
        isErc1155[4] = false;

        uint[] memory floorPrices = new uint[](5);
        floorPrices[0] = 1 ether;
        floorPrices[1] = 1 ether;
        floorPrices[2] = 1 ether;
        floorPrices[3] = 1 ether;
        floorPrices[4] = 1 ether;

        // Create a new collection war for the next epoch
        newCollectionWars.createFloorWar(epochManager.currentEpoch() + 2, collections, isErc1155, floorPrices);

    }

}
