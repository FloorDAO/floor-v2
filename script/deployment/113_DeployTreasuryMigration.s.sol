// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MigrateTreasury} from '@floor/migrations/MigrateTreasury.sol';
import {VestingClaim} from '@floor/migrations/VestingClaim.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our Treaasury and Vesting Claim migration contracts.
 */
contract DeployTreasuryMigration is DeploymentScript {
    function run() external deployer {
        // Get our deployed FLOOR token
        address floorToken = requireDeployment('FloorToken');

        // Set our old and new Treasury values
        address oldTreasury = 0x91E453f442d25523F42063E1695390e325076ca2;
        address newTreasury = requireDeployment('Treasury');

        // Deploy our migration contracts
        MigrateTreasury migrateTreasury = new MigrateTreasury(oldTreasury, newTreasury);
        VestingClaim vestingClaim = new VestingClaim(floorToken, DEPLOYMENT_WETH, newTreasury);

        // Store our deployment addresses
        storeDeployment('MigrateTreasury', address(migrateTreasury));
        storeDeployment('VestingClaim', address(vestingClaim));
    }
}
