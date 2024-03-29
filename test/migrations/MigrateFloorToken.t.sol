// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {MigrateFloorToken} from '@floor/migrations/MigrateFloorToken.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';

// Mocked contract imports for Sepolia deployments
import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {GFloorMock} from '../../test/mocks/GFloor.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract MigrateFloorTokenTest is FloorTest {
    FLOOR newFloor;
    MigrateFloorToken migrateFloorToken;

    /// At block 16016064 we have the following holders good for testing:
    /// ---
    /// FLOOR (1000) : 0xC401d60e25490c14A614c89166b0742e5C677a2d
    /// aFloor (200) : 0xd7Ddf70125342f44E65ccbafAe5135F2bB6526bB
    /// gFloor (500) : 0x544C7D7f4F407b1B55D581CcD563c7Ca8aCfC686
    /// sFloor (310) : 0xc58bDf3d06073987983989eBFA1aC8187161fA71
    uint internal constant BLOCK_NUMBER = 16_016_064;

    event FloorMigrated(address caller, uint amount);

    /**
     * We cannot use our setUp function here, as it causes issues with the
     * {FloorTest} environment when we try and grant a `role`.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Set up our migration contract
        newFloor = new FLOOR(address(authorityRegistry));

        // Define our tokens that will be migrated
        address[] memory migratedTokens = new address[](4);
        migratedTokens[0] = 0xf59257E961883636290411c11ec5Ae622d19455e; // Floor
        migratedTokens[1] = 0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA; // aFloor
        migratedTokens[2] = 0xb1Cc59Fc717b8D4783D41F952725177298B5619d; // gFloor
        migratedTokens[3] = 0x164AFe96912099543BC2c48bb9358a095Db8e784; // sFloor

        // Set up a floor migration contract
        migrateFloorToken = new MigrateFloorToken(
            address(newFloor),
            migratedTokens,
            migratedTokens[2]
        );

        // Give our Floor token migration contract the role to mint floor
        // tokens directly.
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(migrateFloorToken));
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
            0xf59257E961883636290411c11ec5Ae622d19455e, 0xC401d60e25490c14A614c89166b0742e5C677a2d, 1000000000000000000000, true
        );

        // Test aFLOOR
        assertTokenTransfer(
            0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA, 0xd7Ddf70125342f44E65ccbafAe5135F2bB6526bB, 200000000000000000000, true
        );

        // Test gFLOOR
        assertTokenTransfer(
            0xb1Cc59Fc717b8D4783D41F952725177298B5619d, 0x544C7D7f4F407b1B55D581CcD563c7Ca8aCfC686, 1432968497000000000000, true
        );

        // Test sFLOOR
        assertTokenTransfer(
            0x164AFe96912099543BC2c48bb9358a095Db8e784, 0xc58bDf3d06073987983989eBFA1aC8187161fA71, 829614084791000000000, true
        );
    }

    /**
     * If a user does not have a sufficient Floor V1 token balance
     * then the transaction should be reverted.
     */
    function testFail_CannotUpgradeWithInsufficientBalance() public {
        // Test against user with no holdings
        assertTokenTransfer(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, 0xC401d60e25490c14A614c89166b0742e5C677a2d, 0, true);
    }

    /**
     * If a user has not approved the contract to handle their
     * Floor V1 tokens, then the transaction should be reverted.
     */
    function test_CannotUpgradeIfNotApproved() public {
        // Test FLOOR
        assertTokenTransfer(0xf59257E961883636290411c11ec5Ae622d19455e, 0xC401d60e25490c14A614c89166b0742e5C677a2d, 0, false);
    }

    function test_CanMigrateMockTokens() public {
        // Define our tokens that will be migrated
        address[] memory migratedTokens = new address[](4);

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

        // Set up a floor migration contract
        migrateFloorToken = new MigrateFloorToken(
            address(newFloor),
            migratedTokens,
            migratedTokens[2]
        );

        // Give our Floor token migration contract the role to mint floor tokens directly.
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(migrateFloorToken));

        // Mint 100 of each token to our test user
        deal(migratedTokens[0], address(this), 100 * 1e9);
        deal(migratedTokens[1], address(this), 100 * 1e9);
        deal(migratedTokens[2], address(this), 100 * 1e18);
        deal(migratedTokens[3], address(this), 100 * 1e9);

        // Approve our tokens
        ERC20Mock(migratedTokens[0]).approve(address(migrateFloorToken), 100 ether);
        ERC20Mock(migratedTokens[1]).approve(address(migrateFloorToken), 100 ether);
        ERC20Mock(migratedTokens[2]).approve(address(migrateFloorToken), 100 ether);
        ERC20Mock(migratedTokens[3]).approve(address(migrateFloorToken), 100 ether);

        uint expectedBalance = 300 ether + (GFloorMock(migratedTokens[2]).balanceFrom(100 ether) * 1e9);

        // Process our migration
        vm.expectEmit(true, true, false, true, address(migrateFloorToken));
        emit FloorMigrated(address(this), expectedBalance);
        migrateFloorToken.migrateFloorToken();

        // Confirm we have no token balances
        assertEq(ERC20Mock(migratedTokens[0]).balanceOf(address(this)), 0);
        assertEq(ERC20Mock(migratedTokens[1]).balanceOf(address(this)), 0);
        assertEq(ERC20Mock(migratedTokens[2]).balanceOf(address(this)), 0);
        assertEq(ERC20Mock(migratedTokens[3]).balanceOf(address(this)), 0);

        // Confirm we have new token
        assertEq(newFloor.balanceOf(address(this)), expectedBalance);
    }

    function assertTokenTransfer(address _token, address _account, uint _output, bool _approved) private returns (uint) {
        IERC20 token = IERC20(_token);

        // We want to capture our user's initial balances
        uint initialBalance = token.balanceOf(_account);
        uint initialNewTokenBalance = newFloor.balanceOf(_account);

        // Set up our requests to be sent from the test user
        vm.startPrank(_account);

        // If our token is asserted to be approved, then approve our initial balance
        // to be approved for the token.
        if (_approved) {
            token.approve(address(migrateFloorToken), initialBalance);
        }

        // If the token is asserted to be approved, then we want to expect an event
        // to be emitted from the floor token migration contract.
        if (_approved) {
            vm.expectEmit(true, true, false, true, address(migrateFloorToken));
            emit FloorMigrated(_account, _output);
        }

        // If our token is not asserted to be approved, then we want to expect a
        // revert to be triggered.
        if (!_approved) {
            vm.expectRevert('ERC20: transfer amount exceeds allowance');
        }

        // Run our floor token migration contract
        migrateFloorToken.migrateFloorToken();

        // We can now stop pranking as the test user
        vm.stopPrank();

        // If our token was approved, then we need to ensure that the test user's
        // initial token balance is now wiped, and we have a 1:1 mapping to our new
        // token's balance.
        if (_approved) {
            // User should now have a 0 balance of old token
            assertEq(token.balanceOf(_account), 0);

            // User should now have same as the initial balance
            assertEq(newFloor.balanceOf(_account), initialNewTokenBalance + _output);

            return initialBalance;
        }

        // If our token was not approved then we don't expect the initial, or new
        // token, balances to have changed.

        // User should not have changed in their token balance
        assertEq(token.balanceOf(_account), initialBalance);

        // User should have the same amount of new token balance as before
        assertEq(newFloor.balanceOf(_account), initialNewTokenBalance);

        return 0;
    }
}
