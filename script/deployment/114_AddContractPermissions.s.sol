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
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        // Ensure we have required contracts already deployed that will receive roles
        address migrateFloorToken = requireDeployment('MigrateFloorToken');
        address registerSweep = requireDeployment('RegisterSweepTrigger');
        address treasury = requireDeployment('Treasury');
        address veFloorStaking = requireDeployment('VeFloorStaking');
        address vestingClaim = requireDeployment('VestingClaim');

        // We define our roles here, rather than making lots of calls
        bytes32 EPOCH_TRIGGER = keccak256('EpochTrigger');
        bytes32 FLOOR_MANAGER = keccak256('FloorManager');
        bytes32 GUARDIAN = keccak256('Guardian');
        bytes32 TREASURY_MANAGER = keccak256('TreasuryManager');
        bytes32 STRATEGY_MANAGER = keccak256('StrategyManager');
        bytes32 VOTE_MANAGER = keccak256('VoteManager');

        // Allow our specified contracts to mint Floor tokens
        authorityRegistry.grantRole(FLOOR_MANAGER, migrateFloorToken);
        authorityRegistry.grantRole(FLOOR_MANAGER, treasury);
        authorityRegistry.grantRole(FLOOR_MANAGER, vestingClaim);

        // Allow specified contracts and wallets permission to interact with Treasury
        authorityRegistry.grantRole(TREASURY_MANAGER, treasury);

        // Allow specified contracts and wallets permission to create and pause Vaults
        authorityRegistry.grantRole(STRATEGY_MANAGER, treasury);

        // RegisterSweep needs a range of authorities
        authorityRegistry.grantRole(EPOCH_TRIGGER, registerSweep);
        authorityRegistry.grantRole(TREASURY_MANAGER, registerSweep);
        authorityRegistry.grantRole(STRATEGY_MANAGER, registerSweep);

        // VeFloorStaking needs to be VOTE_MANAGER
        authorityRegistry.grantRole(VOTE_MANAGER, veFloorStaking);

        // Approve our guardian
        authorityRegistry.grantRole(GUARDIAN, 0xA9d93A5cCa9c98512C8C56547866b1db09090326);  // mainnet
        // authorityRegistry.grantRole(GUARDIAN, 0x153c6D23fBB4D92335430e33882e575C5e81964A);  // sepolia

        // Transfer ownership of any required contracts
        // None currently required..
    }
}
