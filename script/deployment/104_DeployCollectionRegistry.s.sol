// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our collection registry and approves our default collections.
 */
contract DeployCollectionRegistry is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        address authorityControl = requireDeployment('AuthorityControl');

        // Deploy our {CollectionRegistry} contract
        CollectionRegistry collectionRegistry = new CollectionRegistry(authorityControl);

        // Register WETH as an approved collection
        collectionRegistry.approveCollection(DEPLOYMENT_WETH);

        // Store our collection registry deployment address
        storeDeployment('CollectionRegistry', address(collectionRegistry));
    }
}
