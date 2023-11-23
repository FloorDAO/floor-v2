// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 */
contract UpdateStrategiesAndFundFloorTokens is DeploymentScript {

    function run() external deployer {

        FLOOR floor = FLOOR(requireDeployment('FloorToken'));
        CollectionRegistry collectionRegistry = CollectionRegistry(requireDeployment('CollectionRegistry'));
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Send FLOOR to these addresses
        floor.mint(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, 20000 ether);
        floor.mint(0x0f294726A2E3817529254F81e0C195b6cd0C834f, 10000 ether);
        floor.mint(0x329393e440fD67ba84296a6D64DE42eE79DdD0Bd, 15000 ether);
        floor.mint(0x84f4840E47199F1090cEB108f74C5F332219539A, 25000 ether);
        floor.mint(0x51200AA490F8DF9EBdC9671cF8C8F8A12c089fDa, 20000 ether);

        // Add these collections
        collectionRegistry.approveCollection(0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7);  // CryptoPunks
        collectionRegistry.approveCollection(0x18F6CF0E62C438241943516C1ac880188304620C);  // Cool Cats
        collectionRegistry.approveCollection(0x056207f8Da23Ff08f1F410c1b6F4Bc7767229497);  // Doodles

        // Remove the MOCK collections
        collectionRegistry.unapproveCollection(0x572567C9aC029bd617CdBCF43b8dcC004A3D1339);
        collectionRegistry.unapproveCollection(0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018);
        collectionRegistry.unapproveCollection(0xDc110028492D1baA15814fCE939318B6edA13098);

        // Approve the {Treasury} to use all our ERC721 collections
        IERC721(0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7).setApprovalForAll(address(treasury), true);
        IERC721(0x18F6CF0E62C438241943516C1ac880188304620C).setApprovalForAll(address(treasury), true);
        IERC721(0x056207f8Da23Ff08f1F410c1b6F4Bc7767229497).setApprovalForAll(address(treasury), true);

        // Deposit the token IDs held by the wallet
        for (uint i = 120; i <= 169; ++i) {
            treasury.depositERC721(0x056207f8Da23Ff08f1F410c1b6F4Bc7767229497, i);
        }

        for (uint i = 281; i <= 330; ++i) {
            treasury.depositERC721(0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7, i);
        }

        for (uint i = 270; i <= 319; ++i) {
            treasury.depositERC721(0x18F6CF0E62C438241943516C1ac880188304620C, i);
        }

    }

}
