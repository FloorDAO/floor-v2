// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';


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

    function run() external {
        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast();

        // Set up our {RewardsLedger} to be a {FLOOR_MANAGER} so that it can correctly
        // mint Floor and veFloor on claims.
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(rewards));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(rewards));

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));

        // Give our Floor token migration contract the role to mint floor tokens directly
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(migrateFloorToken));

        // Grant our {veFloorStaking} contract the authority to manage veFloor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(veFloorStaking));

        // We need to allow our {VeFloorStaking} contract to have {VOTE_MANAGER} permissions
        // so that we can trigger vote revoke calls.
        authorityRegistry.grantRole(authorityControl.VOTE_MANAGER(), address(veFloorStaking));

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }

}
