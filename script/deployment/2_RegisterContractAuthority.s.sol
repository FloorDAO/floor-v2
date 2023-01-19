// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../../src/contracts/authorities/AuthorityControl.sol";
import "../../src/contracts/authorities/AuthorityRegistry.sol";

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
    address constant REWARDS_LEDGER = address(0);
    address constant TREASURY = address(0);
    address constant VE_FLOOR_STAKING = address(0);

    function run() external {
        // Load our authority contracts
        AuthorityControl authorityControl = AuthorityControl(AUTHORITY_CONTROL);
        AuthorityRegistry authorityRegistry = AuthorityRegistry(AUTHORITY_REGISTRY);

        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast();

        // Set up our {RewardsLedger} to be a {FLOOR_MANAGER} so that it can correctly
        // mint Floor and veFloor on claims.
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(REWARDS_LEDGER));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(REWARDS_LEDGER));

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(TREASURY));

        // Give our Floor token migration contract the role to mint floor tokens directly
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(MIGRATE_FLOOR_TOKEN));

        // Grant our {veFloorStaking} contract the authority to manage veFloor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(VE_FLOOR_STAKING));

        // We need to allow our {VeFloorStaking} contract to have {VOTE_MANAGER} permissions
        // so that we can trigger vote revoke calls.
        authorityRegistry.grantRole(authorityControl.VOTE_MANAGER(), address(VE_FLOOR_STAKING));

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }
}
