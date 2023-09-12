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
        collectionRegistry.approveCollection(
            0xDc110028492D1baA15814fCE939318B6edA13098,
            address(1)
        );

        collectionRegistry.approveCollection(
            0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018,
            address(1)
        );

        collectionRegistry.approveCollection(
            0x572567C9aC029bd617CdBCF43b8dcC004A3D1339,
            address(1)
        );
    }
}
