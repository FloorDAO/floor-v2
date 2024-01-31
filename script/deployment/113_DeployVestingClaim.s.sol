// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {VestingClaim} from '@floor/migrations/VestingClaim.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our Treaasury and Vesting Claim migration contracts.
 */
contract DeployVestingClaim is DeploymentScript {
    function run() external deployer {
        address floorToken = requireDeployment('FloorToken');
        address newTreasury = requireDeployment('Treasury');

        VestingClaim vestingClaim = new VestingClaim(floorToken, DEPLOYMENT_WETH, newTreasury);

        storeDeployment('VestingClaim', address(vestingClaim));
    }
}
