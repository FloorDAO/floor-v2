// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract PrepareSepolia is DeploymentScript {

    function run() external deployer {

        // add a "stETH" collection (Sepolia UNI: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984)
        CollectionRegistry collectionRegistry = CollectionRegistry(requireDeployment('CollectionRegistry'));
        // collectionRegistry.approveCollection(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

        // bump sampleSize to 2
        SweepWars sweepWars = SweepWars(requireDeployment('SweepWars'));
        // sweepWars.setSampleSize(2);

        // AFTER Floor War 10: removeCollection for Pudgy Pengs

        // AFTER Floor War 10: approve floor war 10 winner

    }

}
