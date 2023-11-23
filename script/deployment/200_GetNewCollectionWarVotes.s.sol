// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract GetNewCollectionWarVotes is DeploymentScript {

    address[] collections = [
        0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7,
        0x4dB1E9Aa44cd6a8F01d13D286149AE7664e3131F,
        0xB56061B12CD9F97918ac4AF319f17AEd4d7FB13b
    ];

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

    function run() external {

        NewCollectionWars newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        uint currentWarIndex = 1;

        console.log('--- Collection Votes ---');

        for (uint i; i < collections.length; ++i) {
            bytes32 warCollection = keccak256(abi.encode(currentWarIndex, collections[i]));
            console.log(collections[i]);
            console.log(newCollectionWars.collectionVotes(warCollection));
        }

        console.log('');
        console.log('--- Wallet Votes ---');

        for (uint i; i < wallets.length; ++i) {
            bytes32 warUser = keccak256(abi.encode(currentWarIndex, wallets[i]));
            console.log(wallets[i]);
            console.log(newCollectionWars.userCollectionVote(warUser));
        }

    }

}
