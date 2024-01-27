// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FLOOR} from '@floor/tokens/Floor.sol';
import {MigrateFloorToken} from '@floor/migrations/MigrateFloorToken.sol';

// Mocked contract imports for Sepolia deployments
import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {GFloorMock} from '../../test/mocks/GFloor.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our Floor token and migration contracts.
 */
contract DeployFloorToken is DeploymentScript {
    function run() external deployer {
        // Get our authority control contract
        address authorityControl = requireDeployment('AuthorityControl');

        // Deploy our new Floor token
        FLOOR floor = new FLOOR(authorityControl);
        // FLOOR floor = FLOOR(requireDeployment('FloorToken'));

        address[] memory migratedTokens = new address[](4);

        // Mainnet addresses
        migratedTokens[0] = 0xf59257E961883636290411c11ec5Ae622d19455e; // Floor
        migratedTokens[1] = 0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA; // aFloor
        migratedTokens[2] = 0xb1Cc59Fc717b8D4783D41F952725177298B5619d; // gFloor
        migratedTokens[3] = 0x164AFe96912099543BC2c48bb9358a095Db8e784; // sFloor

        /*
        // Sepolia addresses and set their decimal values
        ERC20Mock mockToken1 = new ERC20Mock();
        mockToken1.setDecimals(9);
        ERC20Mock mockToken2 = new ERC20Mock();
        mockToken2.setDecimals(9);
        ERC20Mock mockToken3 = new ERC20Mock();
        mockToken3.setDecimals(9);

        migratedTokens[0] = address(mockToken1);  // Floor
        migratedTokens[1] = address(mockToken2);  // aFloor
        migratedTokens[2] = address(new GFloorMock()); // gFloor
        migratedTokens[3] = address(mockToken3);  // sFloor
        */

        // Deploy our V1 -> V2 Floor token migration script
        MigrateFloorToken migrateFloorToken = new MigrateFloorToken(
            address(floor),
            migratedTokens,
            migratedTokens[2]
        );

        /*
        for (uint i; i < migratedTokens.length; ++i) {
            uint amount = (migratedTokens[i] == migratedTokens[2]) ? 100 ether : 100 * 1e9;

            ERC20Mock(migratedTokens[i]).mint(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, amount);
            ERC20Mock(migratedTokens[i]).mint(0x0781B192F48706310082268A4C037078F2e8B9B0, amount);
            ERC20Mock(migratedTokens[i]).mint(0x1Fac7d853c0a6875E5be1b7A6FeC003dAcE99642, amount);
        }
        */

        // Store our deployment address
        storeDeployment('FloorToken', address(floor));
        storeDeployment('MigrateFloorToken', address(migrateFloorToken));
    }
}
