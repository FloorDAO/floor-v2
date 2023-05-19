// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FLOOR} from '@floor/tokens/Floor.sol';
import {MigrateFloorToken} from '@floor/migrations/MigrateFloorToken.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our Floor token and migration contracts.
 */
contract DeployFloorToken is DeploymentScript {
    function run() external deployer {
        // Get our authority control contract
        address authorityControl = requireDeployment('AuthorityControl');

        // Deploy our new Floor token and the migration script for it
        FLOOR floor = new FLOOR(authorityControl);
        MigrateFloorToken migrateFloorToken = new MigrateFloorToken(address(floor));

        // Store our deployment address
        storeDeployment('FloorToken', address(floor));
        storeDeployment('MigrateFloorToken', address(migrateFloorToken));
    }
}
