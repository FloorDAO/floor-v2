// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import {NFTXSellNFTForETH} from '../../src/contracts/actions/nftx/SellNFTForETH.sol';
import {UniswapSellTokensForETH} from '../../src/contracts/actions/uniswap/SellTokensForETH.sol';
import {AuthorityRegistry} from '../../src/contracts/authorities/AuthorityRegistry.sol';
import {CollectionRegistry} from '../../src/contracts/collections/CollectionRegistry.sol';
import {MigrateFloorToken} from '../../src/contracts/migrations/MigrateFloorToken.sol';
import {UniswapV3PricingExecutor} from '../../src/contracts/pricing/UniswapV3PricingExecutor.sol';
import {VeFloorStaking} from '../../src/contracts/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '../../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import {FLOOR} from '../../src/contracts/tokens/Floor.sol';
import {Vault} from '../../src/contracts/vaults/Vault.sol';
import {VaultFactory} from '../../src/contracts/vaults/VaultFactory.sol';
import {GaugeWeightVote} from '../../src/contracts/voting/GaugeWeightVote.sol';
import {Treasury} from '../../src/contracts/Treasury.sol';

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

        // ..

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }
}
