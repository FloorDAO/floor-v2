// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import '../../src/contracts/authorities/AuthorityControl.sol';
import '../../src/contracts/authorities/AuthorityRegistry.sol';

/**
 * Registers our default contract authorities.
 *
 * This should be run in the following command:
 *
 * ```
 * forge script script/deployment/1_RegisterContractAuthority.s.sol:RegisterContractAuthority \
 *      --rpc-url [RPC URL] \
 *      --broadcast \
 *      -vvvv \
 *      --private-key [PRIVATE KEY]
 * ```
 */
contract RegisterContractAuthority is Script {
    address constant AUTHORITY_CONTROL = address(0);
    address constant AUTHORITY_REGISTRY = address(0);

    address constant MIGRATE_FLOOR_TOKEN = address(0);
    address constant TREASURY = address(0);
    address constant VE_FLOOR_STAKING = address(0);

    function run() external {
        /*
        // Load our authority contracts
        AuthorityControl authorityControl = AuthorityControl(AUTHORITY_CONTROL);
        AuthorityRegistry authorityRegistry = AuthorityRegistry(AUTHORITY_REGISTRY);

        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast();

        // Grant our {veFloorStaking} contract the authority to manage veFloor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(veFloorStaking));

        // We need to allow our {VeFloorStaking} contract to have {VOTE_MANAGER} permissions
        // so that we can trigger vote revoke calls.
        authorityRegistry.grantRole(authorityControl.VOTE_MANAGER(), address(veFloorStaking));

        // Give our Floor token migration contract the role to mint floor
        // tokens directly.
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(migrateFloorToken));

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.REWARDS_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.VAULT_MANAGER(), address(treasury));

        // Give Bob the `TREASURY_MANAGER` role so that he can withdraw if needed
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), bob);

        // Grant our {veFloorStaking} contract the authority to manage veFloor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(veFloorStaking));
        authorityRegistry.grantRole(authorityControl.VOTE_MANAGER(), address(veFloorStaking));

        authorityRegistry.grantRole(authorityControl.STAKING_MANAGER(), address(vaultXTokenImplementation));

        // Stop collecting onchain transactions
        vm.stopBroadcast();
        */
    }
}
