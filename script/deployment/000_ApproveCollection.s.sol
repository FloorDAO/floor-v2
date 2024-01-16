// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our collection registry and approves our default collections.
 */
contract ApproveCollection is DeploymentScript {
    function run() external deployer {
        // Load and cast our Collection Registry
        CollectionRegistry collectionRegistry = CollectionRegistry(requireDeployment('CollectionRegistry'));

        // Set up our approved collections
        collectionRegistry.approveCollection(0x3d7E741B5E806303ADbE0706c827d3AcF0696516);
        collectionRegistry.approveCollection(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6);
        collectionRegistry.approveCollection(0xa807e2a221C6dAAFE1b4A3ED2dA5E8A53fDAf6BE);

        // Approve the WETH token
        collectionRegistry.approveCollection(WETH);
    }
}
