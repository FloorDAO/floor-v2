// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import 'forge-std/Test.sol';

import '../../src/contracts/migrations/MigrateFloorToken.sol';
import '../../src/contracts/tokens/Floor.sol';
import '../../src/interfaces/tokens/Floor.sol';


contract MigrateFloorTokenTest is Test {

    FLOOR newFloor;
    MigrateFloorToken migrateFloorToken;

    /// Store our mainnet fork information
    uint256 mainnetFork;

    /// At block 16016064 we have the following holders good for testing:
    /// ---
    /// FLOOR (1000) : 0xC401d60e25490c14A614c89166b0742e5C677a2d
    /// aFloor (200) : 0xd7Ddf70125342f44E65ccbafAe5135F2bB6526bB
    /// gFloor (500) : 0x544C7D7f4F407b1B55D581CcD563c7Ca8aCfC686
    /// sFloor (310) : 0xc58bDf3d06073987983989eBFA1aC8187161fA71
    uint internal constant BLOCK_NUMBER = 16_016_064;

    event FloorMigrated(address caller, uint amount);

    function setUp() public {
        // Generate a mainnet fork
        mainnetFork = vm.createFork(vm.envString('MAINNET_RPC_URL'));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(BLOCK_NUMBER);

        // Confirm that our block number has set successfully
        assertEq(block.number, BLOCK_NUMBER);

        // Set up our migration contract
        newFloor = new FLOOR();
        migrateFloorToken = new MigrateFloorToken(address(newFloor));

        newFloor.grantRole(keccak256('FloorMinter'), address(migrateFloorToken));
    }

    /**
     * There are a range of V1 tokens that we will need to accept:
     *
     *  - aFloor (alpha token, should already be converted into floor)
     *  - Floor (core token)
     *  - gFloor (governance floor)
     *  - sFloor (staked floor)
     *
     * We will need to ensure each of these are accepted and mint at
     * a 1:1 ratio.
     *
     * The Floor V1 tokens should be burnt.
     */
    function test_CanMigrateAllAcceptedV1TokensToV2() public {
        // Test FLOOR
        assertTokenTransfer(
            0xf59257E961883636290411c11ec5Ae622d19455e,
            0xC401d60e25490c14A614c89166b0742e5C677a2d,
            1000000000000000000000,
            true
        );

        // Test aFLOOR
        assertTokenTransfer(
            0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA,
            0xd7Ddf70125342f44E65ccbafAe5135F2bB6526bB,
            200000000000000000000,
            true
        );

        // Test gFLOOR
        assertTokenTransfer(
            0xb1Cc59Fc717b8D4783D41F952725177298B5619d,
            0x544C7D7f4F407b1B55D581CcD563c7Ca8aCfC686,
            500000000000000000000,
            true
        );

        /*
        // Test sFLOOR
        assertTokenTransfer(
            0x164AFe96912099543BC2c48bb9358a095Db8e784,
            0xc58bDf3d06073987983989eBFA1aC8187161fA71,
            829614084791,
            true
        );
        */
    }

    /**
     * If a user does not have a sufficient Floor V1 token balance
     * then the transaction should be reverted.
     */
    function testFail_CannotUpgradeWithInsufficientBalance() public {
        // Test against user with no holdings
        assertTokenTransfer(
            0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96,
            0xC401d60e25490c14A614c89166b0742e5C677a2d,
            0,
            true
        );
    }

    /**
     * If a user has not approved the contract to handle their
     * Floor V1 tokens, then the transaction should be reverted.
     */
    function test_CannotUpgradeIfNotApproved() public {
        // Test FLOOR
        assertTokenTransfer(
            0xf59257E961883636290411c11ec5Ae622d19455e,
            0xC401d60e25490c14A614c89166b0742e5C677a2d,
            0,
            false
        );
    }

    function assertTokenTransfer(address _token, address _account, uint _output, bool _approved) private returns (uint) {
        IERC20 token = IERC20(_token);

        uint initialBalance = token.balanceOf(_account);
        uint initialNewTokenBalance = newFloor.balanceOf(_account);

        vm.startPrank(_account);

        if (_approved) {
            token.approve(address(migrateFloorToken), initialBalance);
        }

        if (_approved) {
            vm.expectEmit(true, true, false, true, address(migrateFloorToken));
            emit FloorMigrated(_account, _output);
        }

        if (!_approved) {
            vm.expectRevert('ERC20: transfer amount exceeds allowance');
        }

        migrateFloorToken.upgradeFloorToken();
        vm.stopPrank();

        if (_approved) {
            // User should now have a 0 balance of old token
            assertEq(token.balanceOf(_account), 0);

            // User should now have same as the initial balance
            assertEq(newFloor.balanceOf(_account), initialNewTokenBalance + _output);

            return initialBalance;
        }

        // User should not have changed in their token balance
        assertEq(token.balanceOf(_account), initialBalance);

        // User should have the same amount of new token balance as before
        assertEq(newFloor.balanceOf(_account), initialNewTokenBalance);

        return 0;
    }

}
