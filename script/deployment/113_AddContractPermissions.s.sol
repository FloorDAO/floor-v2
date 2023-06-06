// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
 */
contract AddContractPermissions is DeploymentScript {
    function run() external deployer {
        // Load and reference our live authority contracts
        IAuthorityControl authorityControl = IAuthorityControl(requireDeployment('AuthorityRegistry'));
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        // Ensure we have required contracts already deployed that will receive roles
        address migrateFloorToken = requireDeployment('MigrateFloorToken');
        address treasury = requireDeployment('Treasury');
        address vestingClaim = requireDeployment('VestingClaim');

        // Allow our specified contracts to mint Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), migrateFloorToken);
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), treasury);
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), vestingClaim);

        // Allow specified contracts and wallets permission to interact with Treasury
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), treasury);

        // Allow specified contracts and wallets permission to create and pause Vaults
        authorityRegistry.grantRole(authorityControl.VAULT_MANAGER(), treasury);

        // Transfer ownership of any required contracts
        // None currently required..
    }
}
