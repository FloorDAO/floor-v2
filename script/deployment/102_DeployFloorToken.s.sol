// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FLOOR} from '@floor/tokens/Floor.sol';
import {MigrateFloorToken} from '@floor/migrations/MigrateFloorToken.sol';

// Mocked contract imports for Sepolia deployments
import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {GFloorMock} from '../../test/mocks/GFloor.sol';

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our Floor token and migration contracts.
 */
contract DeployFloorToken is DeploymentScript {
    function run() external deployer {
        // Load and reference our live authority contracts
        IAuthorityControl authorityControl = IAuthorityControl(requireDeployment('AuthorityControl'));
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        // Deploy our new Floor token
        FLOOR floor = new FLOOR(address(authorityControl));

        address[] memory migratedTokens = new address[](4);

        // Mainnet addresses
        migratedTokens[0] = 0xf59257E961883636290411c11ec5Ae622d19455e; // Floor
        migratedTokens[1] = 0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA; // aFloor
        migratedTokens[2] = 0xb1Cc59Fc717b8D4783D41F952725177298B5619d; // gFloor
        migratedTokens[3] = 0x164AFe96912099543BC2c48bb9358a095Db8e784; // sFloor

        // Sepolia addresses
        // migratedTokens[0] = 0x8edEF7f24344a3323209fa92A886B838300F5605; // Floor
        // migratedTokens[1] = 0x6C1BEB930BC174Fba5bd3afa61536b4f859338b9; // aFloor
        // migratedTokens[2] = 0x5A76dBc57AbdE4039eC4b2889A628E8D517b85D5; // gFloor
        // migratedTokens[3] = 0xC49c96003D3CbC05d508D34Fd3418BF05c253C39; // sFloor

        // Deploy our V1 -> V2 Floor token migration script
        MigrateFloorToken migrateFloorToken = new MigrateFloorToken(
            address(floor),
            migratedTokens,
            migratedTokens[2]
        );

        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(migrateFloorToken));

        // Store our deployment address
        storeDeployment('FloorToken', address(floor));
        storeDeployment('MigrateFloorToken', address(migrateFloorToken));
    }
}
