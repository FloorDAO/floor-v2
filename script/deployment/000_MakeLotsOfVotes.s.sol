// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * ERC721 collections exist on testnet:
 *
 * 0xDc110028492D1baA15814fCE939318B6edA13098
 * 0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018
 * 0x572567C9aC029bd617CdBCF43b8dcC004A3D1339
 */
contract MakeLotsOfVotes is DeploymentScript {

    address collectionOne   = 0xDc110028492D1baA15814fCE939318B6edA13098;
    address collectionTwo   = 0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018;
    address collectionThree = 0x572567C9aC029bd617CdBCF43b8dcC004A3D1339;

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

    FLOOR floor;
    SweepWars sweepWars;
    VeFloorStaking staking;

    function run() external {

        floor = FLOOR(requireDeployment('FloorToken'));
        sweepWars = SweepWars(requireDeployment('SweepWars'));
        staking = VeFloorStaking(requireDeployment('VeFloorStaking'));

        // Give 1 FLOOR to each of the test wallets and send them some gas
        /*
        vm.startBroadcast(vm.envUint('PRIVATE_KEY'));
        floor.mint(0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348, 10 ether);
        for (uint i; i < wallets.length; ++i) {
            floor.transfer(wallets[i], 1 ether);
            (bool sent,) = wallets[i].call{value: 0.1 ether}('');
            require(sent, "Failed to send Ether");
        }
        vm.stopBroadcast();

        // Each of them need to stake their FLOOR
        for (uint i; i < wallets.length; ++i) {
            _stakeFloor(i);
        }
        */

        // Make a fudge-tonne of votes
        _castVote(0, collectionOne,   0.75 ether);
        _castVote(0, collectionTwo,  -0.25 ether);
        _castVote(1, collectionTwo,   1 ether);
        _castVote(2, collectionThree, 0.25 ether);
        _castVote(2, collectionOne,   0.75 ether);
        _castVote(3, collectionTwo,  -0.5 ether);
        _castVote(3, collectionOne,  -0.25 ether);
        _castVote(3, collectionThree, 0.25 ether);
        _castVote(4, collectionOne,   1 ether);
        _castVote(5, collectionOne,  -1 ether);
        _castVote(6, collectionTwo,   0.75 ether);
        _castVote(6, collectionThree, 0.25 ether);
        _castVote(7, collectionThree, 1 ether);
        _castVote(8, collectionTwo,  -1 ether);
        _castVote(9, collectionOne,   0.5 ether);
        _castVote(9, collectionThree, 0.5 ether);

        // Revoke some votes
        _revokeVotes(0, collectionOne);
        _revokeVotes(2, collectionOne, collectionThree);
        _revokeVotes(4, collectionTwo);  // No votes cast
        _revokeVotes(6, collectionThree);
        _revokeVotes(9, collectionOne);

        // Recast votes as some users
        _castVote(6, collectionTwo, 0.25 ether);
        _castVote(9, collectionOne, -0.5 ether);

    }

    function _castVote(uint walletIndex, address collection, int votes) internal {
        vm.startBroadcast(walletKeys[walletIndex]);
        sweepWars.vote(collection, votes);
        vm.stopBroadcast();
    }

    function _revokeVotes(uint walletIndex, address collectionA) internal {
        address[] memory collections = new address[](1);
        collections[0] = collectionA;

        vm.startBroadcast(walletKeys[walletIndex]);
        sweepWars.revokeVotes(collections);
        vm.stopBroadcast();
    }

    function _revokeVotes(uint walletIndex, address collectionA, address collectionB) internal {
        address[] memory collections = new address[](2);
        collections[0] = collectionA;
        collections[1] = collectionB;

        vm.startBroadcast(walletKeys[walletIndex]);
        sweepWars.revokeVotes(collections);
        vm.stopBroadcast();
    }

    function _stakeFloor(uint walletIndex) internal {
        vm.startBroadcast(walletKeys[walletIndex]);
        floor.approve(address(staking), 1 ether);
        staking.deposit(1 ether, 3);
        vm.stopBroadcast();
    }

}
