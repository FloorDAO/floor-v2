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
        collectionRegistry.approveCollection(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6);
        collectionRegistry.approveCollection(0x7b2a53DAF97Ea7aa31B646e079C4772b6198aE9B);
        collectionRegistry.approveCollection(0x67523B71Bc3eeF7E5d90492aeD7a4B447Bc1deCd);
    }
}
