// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FloorNft} from '@floor/tokens/FloorNft.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our Floor NFT contract.
 */
contract DeployAuthorityRegistry is DeploymentScript {

    function run() external deployer {
        // Create our default Floor NFT contract with an initial max supply
        FloorNft floorNft = new FloorNft(
            'Floor NFT',  // _name
            'nftFloor',   // _symbol
            250,          // _maxSupply
            5             // _maxMintAmountPerTx
        );

        // Store our deployment address
        storeDeployment('FloorNft', address(floorNft));
    }

}
