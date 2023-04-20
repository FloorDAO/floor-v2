// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AuthorityRegistry} from '@floor/authorities/AuthorityRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our authority registry contract.
 */
contract DeployAuthorityRegistry is DeploymentScript {

    function run() external deployer {
        // Deploy our Authority Registry contract. Note that this will give ownership
        // permissions to the address that deploys it.
        AuthorityRegistry authorityRegistry = new AuthorityRegistry();

        // Store our deployment address
        storeDeployment('AuthorityRegistry', address(authorityRegistry));
    }

}
