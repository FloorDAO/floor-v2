// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 *
 */
contract VoteInNewCollectionWar is DeploymentScript {

    address collectionOne   = 0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7;
    address collectionTwo   = 0x4dB1E9Aa44cd6a8F01d13D286149AE7664e3131F;
    address collectionThree = 0xB56061B12CD9F97918ac4AF319f17AEd4d7FB13b;

    address[] wallets = [
        0xb1f5208B6065E5040eE524b6ab0595a0D8eC3de0,
        0xEeCD1Dd555662C34C2221a6D34749A592D2694B3,
        0xbBf2619FB570E80b04080b85Ad3BD77c7301fC75,
        0x06a57d621D0B97Fd5c5A671B9F15629556C57a87,
        0x035fe3255B1d4a999e71e28bD344bE8DCf80F7a9,
        0xA7D92aFCA3034bD3506aF3E514Fe3D77896bBEBD,
        0x77a9e9477131f8266210329732d42Cd815E114FD,
        0x87B6C517e52dA2E20943448352557293305481B7,
        0xe03f98d16969C406f52F5D6AC76518610B5cED63,
        0xB9A8C364382ed16F8889fcB691a9a20dE5a65944
    ];

    uint[] walletKeys = [
        uint(0x2f9c92e3f66e0da95ffe7d5dbe7b552c35a8265ff7badf1c190604d5bf430787),
        uint(0xeaeb39f7ac53d7c5db07795cabf84d225e12453eae30f6d2e703d2b18949d675),
        uint(0xfb12c9987181415a2d84aa9992023195e05c912c10d97610b5e2691583bdd15f),
        uint(0x436b4b2de2efee40afb0ac1ac303a7187b1615138c889d7f9fddccae1b4536f4),
        uint(0x35dc28d6b1e51697f43336414c33c0bb59e18711fcb5b0c1dd7db25d2633e187),
        uint(0xe4208e507376d15e75d20a3b86da699864e9418d4fe8f62845297ea3d257580c),
        uint(0xa976e58fce531c4e6d92e5a3c5f25077e7a8c1bd4749d21c02d8cb4426d58ad5),
        uint(0x92fc4d892ba73e4f11cf64b94681e3050601dccd2b77d87875a0c56dd9f18193),
        uint(0x45c55f893a5d1d8ceb78d59d83ab196c2a29530571c349b46dbd933752061996),
        uint(0x4a0a8888778cae5ce2fbd169c34c755beeca994b2aa367d6e7f18e186a2716ed)
    ];

    EpochManager epochManager;
    NewCollectionWars newCollectionWars;

    function run() external {

        // Load our seed phrase from a protected file
        uint privateKey = vm.envUint('PRIVATE_KEY');

        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast(privateKey);

        // Deploy our new {NewCollectionWars} contract
        epochManager = EpochManager(requireDeployment('EpochManager'));
        newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        address[] memory collections = new address[](3);
        collections[0] = collectionOne;
        collections[1] = collectionTwo;
        collections[2] = collectionThree;

        bool[] memory isErc1155 = new bool[](3);
        isErc1155[0] = false;
        isErc1155[1] = false;
        isErc1155[2] = false;

        uint[] memory floorPrices = new uint[](3);
        floorPrices[0] = 1 ether;
        floorPrices[1] = 1 ether;
        floorPrices[2] = 1 ether;

        // Create a new collection war for the next epoch
        newCollectionWars.createFloorWar(epochManager.currentEpoch() + 1, collections, isErc1155, floorPrices);

        // End the current epoch and move into our new collection war
        epochManager.endEpoch();

        // Stop collecting onchain transactions
        vm.stopBroadcast();

        // Make a fudge-tonne of votes
        _castVote(0, collectionOne);
        _castVote(1, collectionTwo);
        _castVote(2, collectionOne);
        _castVote(3, collectionThree);
        _castVote(5, collectionOne);
        _castVote(6, collectionTwo);
        _castVote(7, collectionThree);
        _castVote(8, collectionTwo);
        _castVote(9, collectionOne);

        // Revoke some votes
        _revokeVotes(0);
        _revokeVotes(2);
        _revokeVotes(9);

        // Change the votes
        _castVote(1, collectionTwo);
        _castVote(4, collectionThree);
        _castVote(6, collectionTwo);
        _castVote(9, collectionOne);

    }

    function _castVote(uint walletIndex, address collection) internal {
        vm.startBroadcast(walletKeys[walletIndex]);
        newCollectionWars.vote(collection);
        vm.stopBroadcast();
    }

    function _revokeVotes(uint walletIndex) internal {
        vm.startBroadcast(walletKeys[walletIndex]);
        newCollectionWars.revokeVotes(wallets[walletIndex]);
        vm.stopBroadcast();
    }

}
