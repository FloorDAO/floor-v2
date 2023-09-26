// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {AuthorityRegistry} from '@floor/authorities/AuthorityRegistry.sol';

import {IEpochManager} from '@floor-interfaces/EpochManager.sol';

contract FloorTest is Test {
    using stdStorage for StdStorage;

    AuthorityControl authorityControl;
    AuthorityRegistry authorityRegistry;

    address payable[] users;

    /// Store our deployer address
    address constant DEPLOYER = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    bytes32 internal nextUser = keccak256(abi.encodePacked('user address'));

    constructor() {
        // Set up a small pool of test users
        createUsers(5);

        // Label our users
        vm.label(users[0], 'Alice');
        vm.label(users[1], 'Bob');
        vm.label(users[2], 'Carol');
        vm.label(users[3], 'David');
        vm.label(users[4], 'Earl');
    }

    function _deployAuthority() internal {
        // Set up our authority registry
        authorityRegistry = new AuthorityRegistry();

        // Attach our registry control to our control contract
        authorityControl = new AuthorityControl(address(authorityRegistry));
    }

    /**
     * Sets up the logic to fork from a mainnet block, based on just an integer passed.
     *
     * @dev This should be applied to a constructor.
     */
    modifier forkBlock(uint blockNumber) {
        // Generate a mainnet fork
        uint mainnetFork = vm.createFork(vm.rpcUrl('mainnet'));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(blockNumber);

        // Confirm that our block number has set successfully
        require(block.number == blockNumber);
        _;
    }

    /**
     * Tests if a value is within a certain variance of another value.
     */
    function assertAlmostEqual(uint a, uint b, uint v) internal {
        assertGt(a, v);
        assertGt(b, v);
        assertTrue(a - v < b || a + v > b);
    }

    /**
     * Tests if a value is within a certain variance of another value, supporting int values.
     */
    function assertAlmostEqual(int a, int b, int v) internal {
        assertTrue(a - v < b || a + v > b);
    }

    /**
     * Implements a common strategy initialisation bytes.
     */
    function _strategyInitBytes() internal pure returns (bytes memory) {
        return abi.encode(
            0, // _vaultId
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _underlyingToken
            0x08765C76C758Da951DC73D3a8863B34752Dd76FB, // _yieldToken
            0x3E135c3E981fAe3383A5aE0d323860a34CfAB893, // _inventoryStaking
            0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, // _stakingZap
            0x2374a32ab7b4f7BE058A69EA99cb214BFF4868d3 // _unstakingZap
        );
    }

    /**
     * Allows the current epoch to be manipulated
     */
    function setCurrentEpoch(address epochManager, uint epoch) internal {
        // Manually target and store a new epoch
        stdstore.target(epochManager).sig('currentEpoch()').checked_write(epoch);

        // Confirm that the current epoch has been correctly updated
        assertEq(IEpochManager(epochManager).currentEpoch(), epoch);
    }

    /**
     * Variation of our createUsers functions that does not require labels or
     * an `initialFund`, but instead just defaults to give 100 ether.
     */
    function createUsers(uint userNum) public {
        for (uint i = 0; i < userNum; ++i) {
            // Add the user to our return array
            address payable user = getNextUserAddress();
            users.push(user);
        }
    }

    /**
     * Generates a new user address that we can use.
     */
    function getNextUserAddress() private returns (address payable) {
        // bytes32 to address conversion
        address payable user = payable(address(uint160(uint(nextUser) + users.length)));
        nextUser = keccak256(abi.encodePacked(nextUser));
        return user;
    }
}
