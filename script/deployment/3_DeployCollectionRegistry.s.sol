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
        address authorityRegistry = requireDeployment('AuthorityRegistry');
        address floorNft = requireDeployment('FloorNft');

        // Deploy our {CollectionRegistry} contract
        CollectionRegistry collectionRegistry = new CollectionRegistry(authorityRegistry);

        // Store our collection registry deployment address
        storeDeployment('CollectionRegistry', address(collectionRegistry));

        // Set up our approved collections
        collectionRegistry.approveCollection(  // PUNK
            0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB,
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A
        );
        collectionRegistry.approveCollection(  // WIZARD
            0x521f9C7505005CFA19A8E5786a9c3c9c9F5e6f42,
            0x87931E7AD81914e7898d07c68F145fC0A553D8Fb
        );
        collectionRegistry.approveCollection(  // MAYC
            0x60E4d786628Fea6478F785A6d7e704777c86a7c6,
            0x94c9cEb2F9741230FAD3a62781b27Cc79a9460d4
        );  //
        collectionRegistry.approveCollection(  // MILADY
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5,
            0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48
        );
        collectionRegistry.approveCollection(  // SQGL
            0x059EDD72Cd353dF5106D2B9cC5ab83a52287aC3a,
            0x8d137e3337eb1B58A222Fef2B2Cc7C423903d9cf
        );
        collectionRegistry.approveCollection(  // BGAN
            0x31385d3520bCED94f77AaE104b406994D8F2168C,
            0xc3B5284B2c0cfa1871a6ac63B6d6ee43c08BDC79
        );
        collectionRegistry.approveCollection(  // ENS (NNNN)
            0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85,
            0x614A0C75B1574748634Dea378a7044F614b6Fd9d
        );
        collectionRegistry.approveCollection(  // SAUDIS
            0xe21EBCD28d37A67757B9Bc7b290f4C4928A430b1,
            0x9332Ad7F5a8B75024662588b7eEe450C513ef9ac
        );
        collectionRegistry.approveCollection(  // REMIO
            0xD3D9ddd0CF0A5F0BFB8f7fcEAe075DF687eAEBaB,
            0xa35Bd2246978Dfbb1980DFf8Ff0f5834335dFdbc
        );
        collectionRegistry.approveCollection(  // FLOOR
            floorNft,
            address(0)
        );
    }

}
