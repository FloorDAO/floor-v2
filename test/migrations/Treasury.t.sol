// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {MigrateTreasury} from '@floor/migrations/MigrateTreasury.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {Treasury} from '@floor/Treasury.sol';

import {ILegacyTreasury} from '@floor-interfaces/legacy/Treasury.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract MigrateFloorTokenTest is FloorTest {
    ILegacyTreasury legacyTreasury;
    MigrateTreasury migrateTreasury;
    Treasury treasury;

    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant LEGACY_TREASURY = 0x91E453f442d25523F42063E1695390e325076ca2;

    uint internal constant BLOCK_NUMBER = 17_385_629;

    event TokenMigrated(address token, uint received, uint sent);

    /**
     *
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Set up our {Floor} token
        FLOOR floor = new FLOOR(address(authorityRegistry));

        // Set up our {Treasury}
        treasury = new Treasury(address(authorityRegistry), address(floor), WETH);
        legacyTreasury = ILegacyTreasury(LEGACY_TREASURY);

        // Set up a floor migration contract
        migrateTreasury = new MigrateTreasury(LEGACY_TREASURY, address(treasury));
    }

    /**
     *
     */
    function test_CanMigrateTokens() public hasLegacyPermission {
        migrateTreasury.migrate(_knownTokens());
    }

    /**
     *
     */
    function test_CanMigrateUnknownTokensWithoutRevert() public hasLegacyPermission {
        migrateTreasury.migrate(_unknownTokens());
    }

    /**
     *
     */
    function test_CannotMigrateTokensWithoutLegacyPermissions() public {
        vm.expectRevert();
        migrateTreasury.migrate(_knownTokens());
    }

    /**
     *
     */
    function test_CannotMigrateTokensWithoutOwnablePermissions() public hasLegacyPermission {
        vm.startPrank(users[1]);

        vm.expectRevert();
        migrateTreasury.migrate(_knownTokens());

        vm.stopPrank();
    }

    /**
     *
     */
    function _knownTokens() internal pure returns (address[] memory tokens) {
        tokens = new address[](12);
        tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens[1] = 0xFB2f1C0e0086Bcef24757C3b9bfE91585b1A280f;
        tokens[2] = 0x08765C76C758Da951DC73D3a8863B34752Dd76FB;
        tokens[3] = 0x7BBec59e6b6Bd75Df4F57927C3c6A42D9d39728E;
        tokens[4] = 0x1EA1ccFecc55938A71c67150C41e7eBA0743e94c;
        tokens[5] = 0xC7eC3aC4c4014384Bb6B09e01400CEFF6D1961E6;
        tokens[6] = 0x6c6BCe43323f6941FD6febe8ff3208436e8e0Dc7;
        tokens[7] = 0x269616D549D7e8Eaa82DFb17028d0B212D11232A;
        tokens[8] = 0x94c9cEb2F9741230FAD3a62781b27Cc79a9460d4;
        tokens[9] = 0x87931E7AD81914e7898d07c68F145fC0A553D8Fb;
        tokens[10] = 0x8d137e3337eb1B58A222Fef2B2Cc7C423903d9cf;
        tokens[11] = 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48;
    }

    /**
     *
     */
    function _unknownTokens() internal pure returns (address[] memory tokens) {
        tokens = new address[](4);
        tokens[0] = 0xD56daC73A4d6766464b38ec6D91eB45Ce7457c44;
        tokens[1] = 0x107c4504cd79C5d2696Ea0030a8dD4e92601B82e;
        tokens[2] = 0x111111111117dC0aa78b770fA6A738034120C302;
        tokens[3] = 0xFC7932eFf0Ead5c96756215111be2e5d34244f3F;
    }

    modifier hasLegacyPermission() {
        vm.startPrank(0xA9d93A5cCa9c98512C8C56547866b1db09090326);
        legacyTreasury.enable(uint8(13), address(migrateTreasury), address(0));
        vm.stopPrank();

        _;
    }
}
