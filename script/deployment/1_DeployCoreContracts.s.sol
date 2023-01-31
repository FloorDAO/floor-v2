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
import {NFTXLiquidityStakingStrategy} from '../../src/contracts/strategies/NFTXLiquidityStakingStrategy.sol';
import {StrategyRegistry} from '../../src/contracts/strategies/StrategyRegistry.sol';
import {FLOOR} from '../../src/contracts/tokens/Floor.sol';
import {VaultXToken} from '../../src/contracts/tokens/VaultXToken.sol';
import {Vault} from '../../src/contracts/vaults/Vault.sol';
import {VaultFactory} from '../../src/contracts/vaults/VaultFactory.sol';
import {GaugeWeightVote} from '../../src/contracts/voting/GaugeWeightVote.sol';
import {Treasury} from '../../src/contracts/Treasury.sol';
import {ClaimFloorRewardsZap} from '../../src/contracts/zaps/ClaimFloorRewards.sol';

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

        // Deploy our {AuthorityRegistry}; our authority roles will be deployed in a
        // subsequent script.
        AuthorityRegistry authorityRegistry = new AuthorityRegistry();

        // Deploy our registry contracts
        CollectionRegistry collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        StrategyRegistry strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Deploy our {Vault} implementation
        Vault vaultImplementation = new Vault();

        // Deploy our {VaultXToken} implementation
        VaultXToken vaultXTokenImplementation = new VaultXToken();

        // Deploy our tokens
        FLOOR floor = new FLOOR(address(authorityRegistry));
        // VeFloorStaking veFloor = new VeFloorStaking();

        /*
        // Deploy our NFTX staking strategies
        NFTXInventoryStakingStrategy inventoryStakingStrategy = new NFTXInventoryStakingStrategy('NFTX Inventory Staking');
        NFTXLiquidityStakingStrategy liquidityStakingStrategy = new NFTXLiquidityStakingStrategy('NFTX Liquitity Staking');

        // Deploy our pricing executor
        UniswapV3PricingExecutor pricingExecutor = new UniswapV3PricingExecutor(0x1F98431c8aD98523631AE4a59f267346ea31F984, address(floor));

        // Deploy our {VaultFactory}
        VaultFactory vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            address(vaultImplementation),
            address(vaultXTokenImplementation),
            address(floor)
        );

        // Deploy our {Treasury}
        Treasury treasury = new Treasury(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            address(vaultFactory),
            address(floor)
        );

        // Deploy our {GaugeWeightVote}
        GaugeWeightVote gaugeWeightVote = new GaugeWeightVote(
            address(collectionRegistry),
            address(vaultFactory),
            address(veFloor),
            address(authorityRegistry)
        );

        // Deploy our Staking contract(s)
        VeFloorStaking veFloorStaking = new VeFloorStaking(
            address(authorityRegistry),
            floor,
            veFloor,
            gaugeWeightVote,
            1 ether,
            1 ether,
            5,
            50,
            20000
        );

        // Deploy our {Treasury} actions
        NFTXSellNFTForETH nftxSellNFTForETH = new NFTXSellNFTForETH(0x941A6d105802CCCaa06DE58a13a6F49ebDCD481C, address(treasury));
        UniswapSellTokensForETH uniswapSellTokensForETH = new UniswapSellTokensForETH(0xE592427A0AEce92De3Edee1F18E0157C05861564, address(treasury));

        // Deploy our migrations
        MigrateFloorToken migrateFloorToken = new MigrateFloorToken(address(floor));

        // Deploy our zaps
        ClaimFloorRewardsZap claimFloorRewardsZap = new ClaimFloorRewardsZap(address(floor), address(vaultFactory));
        */

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }

}
