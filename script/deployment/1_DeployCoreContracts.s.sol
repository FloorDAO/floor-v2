// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';


/**
 * Deploys our contracts and validates them on Etherscan.
 *
 * This should be run in the following command:
 *
 * ```
 * forge script script/deployment/1_DeployCoreContracts.s.sol:DeployCoreContracts \
 *      --rpc-url [RPC URL] \
 *      --broadcast \
 *      --verify \
 *      -vvvv \
 *      --private-key [PRIVATE KEY]
 * ```
 */
contract DeployCoreContracts is Script {

    function run() external {
        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast();

        // Enter contracts here.

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }
}
