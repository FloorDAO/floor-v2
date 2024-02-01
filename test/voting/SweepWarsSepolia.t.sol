// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {SweepWars} from '@floor/voting/SweepWars.sol';

import {FloorTest} from '../utilities/Environments.sol';


contract SweepWarsSepolia is FloorTest {

    address public constant QUAG = 0x1Fac7d853c0a6875E5be1b7A6FeC003dAcE99642;

    function test_CanQuagBeRight() public {

        // Generate a mainnet fork
        uint sepoliaFork = vm.createFork(vm.rpcUrl('sepolia'));

        // Select our fork for the VM
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(5192031);
        require(block.number == 5192031);

        // ..
        SweepWars sweepWars = SweepWars(0x8C790f079edeD31D08De2FA4819724B51a1C2F45);

        uint quagVotesTotal = getMappingValue(address(sweepWars), 5, QUAG);
        console.log('Votes total:');
        console.log(quagVotesTotal);

        address[] memory collections = new address[](7);
        collections[0] = 0x27F2957b2205f417f6a4761Eac9E0920C6c9c3dc;
        collections[1] = 0xa807e2a221C6dAAFE1b4A3ED2dA5E8A53fDAf6BE;
        collections[2] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        collections[3] = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        collections[4] = 0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6;
        collections[5] = 0x3d7E741B5E806303ADbE0706c827d3AcF0696516;
        collections[6] = address(0);

        for (uint i; i < collections.length; ++i) {
            uint votesFor = getMappingValue(address(sweepWars), 3, keccak256(abi.encode(QUAG, collections[i])));
            uint votesAgainst = getMappingValue(address(sweepWars), 4, keccak256(abi.encode(QUAG, collections[i])));

            console.log('Collection:');
            console.log(collections[i]);
            console.log('VotesFor:');
            console.log(votesFor);
            console.log('VotesAgainst:');
            console.log(votesAgainst);
        }
    }

    function getMappingValue(address targetContract, uint256 mapSlot, address key) public view returns (uint256) {
        bytes32 slotValue = vm.load(targetContract, keccak256(abi.encode(key, mapSlot)));
        return uint256(slotValue);
    }

    function getMappingValue(address targetContract, uint256 mapSlot, bytes32 key) public view returns (uint256) {
        bytes32 slotValue = vm.load(targetContract, keccak256(abi.encode(key, mapSlot)));
        return uint256(slotValue);
    }

}
