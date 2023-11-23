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

    address collectionOne   = 0x4dB1E9Aa44cd6a8F01d13D286149AE7664e3131F;  // Milady
    address collectionTwo   = 0xD643e0B909867025b50375D7495e7d0f6F85De5f;  // Bored Apes
    address collectionThree = 0xB56061B12CD9F97918ac4AF319f17AEd4d7FB13b;  // Pudgy

    EpochManager epochManager;
    NewCollectionWars newCollectionWars;

    function run() external {

        // Load our seed phrase from a protected file
        uint privateKey = vm.envUint('PRIVATE_KEY');

        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast(privateKey);

        // Deploy our new {NewCollectionWars} contract
        epochManager = EpochManager(requireDeployment('EpochManager'));
        newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        address[] memory collections = new address[](3);
        collections[0] = collectionOne;
        collections[1] = collectionTwo;
        collections[2] = collectionThree;

        bool[] memory isErc1155 = new bool[](3);
        isErc1155[0] = false;
        isErc1155[1] = false;
        isErc1155[2] = false;

        uint[] memory floorPrices = new uint[](3);
        floorPrices[0] = 1 ether;
        floorPrices[1] = 1 ether;
        floorPrices[2] = 1 ether;

        // Create a new collection war for the next epoch
        newCollectionWars.createFloorWar(epochManager.currentEpoch() + 1, collections, isErc1155, floorPrices);

        // Stop collecting onchain transactions
        vm.stopBroadcast();

    }

}
