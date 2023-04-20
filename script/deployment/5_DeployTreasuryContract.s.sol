// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our Treasury.
 */
contract DeployCollectionRegistry is DeploymentScript {

    function run() external deployer {

        // Confirm that we have our required contracts deployed
        address authorityRegistry = requireDeployment('AuthorityRegistry');

        // Get our FLOOR token address
        address floorToken = 0xf59257E961883636290411c11ec5Ae622d19455e;

        // Set up our Treasury contract
        Treasury treasury = new Treasury(authorityRegistry, floorToken);

        // Store our {Treasury} contract address
        storeDeployment('Treasury', address(treasury));

    }

}
