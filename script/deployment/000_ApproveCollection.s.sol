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

        // Mainnet collections
        collectionRegistry.approveCollection(0x282BDD42f4eb70e7A9D9F40c8fEA0825B7f68C5D); // WRAPPED PUNK
        collectionRegistry.approveCollection(0x521f9C7505005CFA19A8E5786a9c3c9c9F5e6f42); // WIZARD / Forgotten Runes
        collectionRegistry.approveCollection(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // MILADY
        collectionRegistry.approveCollection(0x059EDD72Cd353dF5106D2B9cC5ab83a52287aC3a); // SQUIGGLE
        collectionRegistry.approveCollection(0x31385d3520bCED94f77AaE104b406994D8F2168C); // BGAN
        collectionRegistry.approveCollection(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85); // ENS
        collectionRegistry.approveCollection(0xe21EBCD28d37A67757B9Bc7b290f4C4928A430b1); // SAUDIS
        collectionRegistry.approveCollection(0xD3D9ddd0CF0A5F0BFB8f7fcEAe075DF687eAEBaB); // REMILLIO
        collectionRegistry.approveCollection(0x09f66a094a0070EBDdeFA192a33fa5d75b59D46b); // YAYO

        // Sepolia collections
        // collectionRegistry.approveCollection(0x3d7E741B5E806303ADbE0706c827d3AcF0696516);
        // collectionRegistry.approveCollection(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6);
        // collectionRegistry.approveCollection(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        // collectionRegistry.approveCollection(0x27F2957b2205f417f6a4761Eac9E0920C6c9c3dc);
    }
}
