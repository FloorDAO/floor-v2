// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our Treasury.
 */
contract DeployTreasuryContract is DeploymentScript {

    function run() external deployer {

        // Confirm that we have our required contracts deployed
        address authorityControl = requireDeployment('AuthorityControl');

        // Get our FLOOR token address
        address floorToken = requireDeployment('FloorToken');

        // Set up our Treasury contract
        Treasury treasury = new Treasury(
            authorityControl,
            floorToken,
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );

        // Store our {Treasury} contract address
        storeDeployment('Treasury', address(treasury));

    }

}
