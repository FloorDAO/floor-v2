// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract MakeLotsMoreVotes is DeploymentScript {

    address collectionOne   = 0x056207f8Da23Ff08f1F410c1b6F4Bc7767229497;
    address collectionTwo   = 0x18F6CF0E62C438241943516C1ac880188304620C;
    address collectionThree = 0x4dB1E9Aa44cd6a8F01d13D286149AE7664e3131F;

    address[] wallets = [
        // New wallets
        0xb0161Ac7998b8800Ee1bF051C702899bd22Bd568,
        0xec497ef66d6DE9835c5008eF62a8C64Ac4dCf3B9,
        0xFbC83Bee6d4e0e71Baf2d7Fe6d63B803A4A92bEA,
        0x927EB3248B9Eb9b098C7360Ad79708AD98AEA022,
        0x0F11CfB4B34f41eacFA3318dA32eE09f5128fA61,

        // Old wallets
        0xA7D92aFCA3034bD3506aF3E514Fe3D77896bBEBD,
        0x77a9e9477131f8266210329732d42Cd815E114FD,
        0x87B6C517e52dA2E20943448352557293305481B7,
        0xe03f98d16969C406f52F5D6AC76518610B5cED63,
        0xB9A8C364382ed16F8889fcB691a9a20dE5a65944
    ];

    uint[] walletKeys = [
        // New wallets
        uint(0x2a3891226c9dd15334433c917bf432cfd8d130dcc4a87460729811342afa7c1b),
        uint(0x6fc2a062a6ffe96e20d0d562dc6d16206ac2ad1a66a981c26ca4b33822b83be4),
        uint(0xef593e3e48b8e9f8873388e386bb2357ec07d484aef22ddf4b0afca23a1a6840),
        uint(0xcf72d6b9b40295e15a7412cc59fad9374c6da05f22fea450ebd2c4de5b12a2a6),
        uint(0xa5e9b72145d6004daadbaa5a56b14edcf84979fd3fcc15f686f16f2877d131df),

        // Old wallets
        uint(0xe4208e507376d15e75d20a3b86da699864e9418d4fe8f62845297ea3d257580c),
        uint(0xa976e58fce531c4e6d92e5a3c5f25077e7a8c1bd4749d21c02d8cb4426d58ad5),
        uint(0x92fc4d892ba73e4f11cf64b94681e3050601dccd2b77d87875a0c56dd9f18193),
        uint(0x45c55f893a5d1d8ceb78d59d83ab196c2a29530571c349b46dbd933752061996),
        uint(0x4a0a8888778cae5ce2fbd169c34c755beeca994b2aa367d6e7f18e186a2716ed)
    ];

    CollectionRegistry collectionRegistry;
    FLOOR floor;
    SweepWars sweepWars;
    VeFloorStaking staking;

    function run() external {

        collectionRegistry = CollectionRegistry(requireDeployment('CollectionRegistry'));
        floor = FLOOR(requireDeployment('FloorToken'));
        sweepWars = SweepWars(requireDeployment('SweepWars'));
        staking = VeFloorStaking(requireDeployment('VeFloorStaking'));

        // Give 1 FLOOR to each of the test wallets and send them some gas
        vm.startBroadcast(vm.envUint('PRIVATE_KEY'));
        collectionRegistry.approveCollection(collectionThree);

        require(collectionRegistry.isApproved(collectionOne), 'collectionOne not approved');
        require(collectionRegistry.isApproved(collectionTwo), 'collectionTwo not approved');
        require(collectionRegistry.isApproved(collectionThree), 'collectionThree not approved');

        floor.mint(0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348, 10 ether);
        for (uint i; i < wallets.length; ++i) {
            floor.transfer(wallets[i], 1 ether);
            (bool sent,) = wallets[i].call{value: 0.1 ether}('');
            require(sent, "Failed to send Ether");
        }
        vm.stopBroadcast();

        // Stake floor for new users
        _stakeFloor(0);
        _stakeFloor(1);
        _stakeFloor(2);
        _stakeFloor(3);
        _stakeFloor(4);

        // Make a fudge-tonne of votes
        _castVote(0, collectionOne,   1 ether);
        _castVote(1, collectionTwo,  -1 ether);
        _castVote(2, collectionTwo,   1 ether);
        _castVote(3, collectionThree, 1 ether);
        _castVote(4, collectionOne,   1 ether);

        // Revoke some votes
        _revokeVotes(5);
        _revokeVotes(6);
        _revokeVotes(7);
        _revokeVotes(8);
        _revokeVotes(9);

        // Recast votes as some users
        _castVote(5, collectionOne,   1 ether);
        _castVote(7, collectionThree, 1 ether);
        _castVote(8, collectionTwo,   1 ether);
        _castVote(9, collectionOne,  -1 ether);
    }

    function _castVote(uint walletIndex, address collection, int votes) internal {
        vm.startBroadcast(walletKeys[walletIndex]);
        sweepWars.vote(collection, votes);
        vm.stopBroadcast();
    }

    function _revokeVotes(uint walletIndex) internal {
        address[] memory collections = new address[](3);
        collections[0] = collectionOne;
        collections[1] = collectionTwo;
        collections[2] = collectionThree;

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
