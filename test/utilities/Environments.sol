// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import '../../src/contracts/authorities/AuthorityControl.sol';
import '../../src/contracts/authorities/AuthorityRegistry.sol';

import '../utilities/Utilities.sol';

contract FloorTest is Test {
    uint mainnetFork;

    AuthorityControl authorityControl;
    AuthorityRegistry authorityRegistry;

    Utilities utilities;
    address payable[] users;

    address constant DEPLOYER = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    constructor() {
        // Set up our utilities class
        utilities = new Utilities();

        // Set up a small pool of test users
        users = utilities.createUsers(5, 100 ether);

        // Label our users
        vm.label(users[0], 'Alice');
        vm.label(users[1], 'Bob');
        vm.label(users[2], 'Carol');
        vm.label(users[3], 'David');
        vm.label(users[4], 'Earl');

        // Set up our authority registry
        authorityRegistry = new AuthorityRegistry();

        // Attach our registry control to our control contract
        authorityControl = new AuthorityControl(address(authorityRegistry));
    }

    modifier forkBlock(uint blockNumber) {
        // Generate a mainnet fork
        mainnetFork = vm.createFork(vm.rpcUrl('mainnet'));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(blockNumber);

        // Confirm that our block number has set successfully
        require(block.number == blockNumber);
        _;
    }

    /**
     * ...
     */
    function assertAlmostEqual(uint a, uint b, uint v) internal {
        assertGt(a, v);
        assertGt(b, v);
        assertTrue(a - v < b || a + v > b);
    }

    /**
     * ...
     */
    function _strategyInitBytes() internal pure returns (bytes memory) {
        return abi.encode(
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _underlyingToken
            0x08765C76C758Da951DC73D3a8863B34752Dd76FB, // _yieldToken
            0x3E135c3E981fAe3383A5aE0d323860a34CfAB893  // _inventoryStaking
        );
    }

}
