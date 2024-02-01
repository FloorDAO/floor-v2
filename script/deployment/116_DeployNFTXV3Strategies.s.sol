// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';
import {NFTXV3Strategy} from '@floor/strategies/NFTXV3Strategy.sol';

import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our strategies and factory contracts.
 */
contract DeployNFTXV3Strategies is DeploymentScript {
    /// The address of the NFTX Router
    // address internal constant NFTX_ROUTER = 0xD36ece08F76c50EC3F01db65BBc5Ef5Aa5fbE849; // Mainnet
    address internal constant NFTX_ROUTER = 0x70A741A12262d4b5Ff45C0179c783a380EebE42a; // Sepolia
    uint24 internal constant POOL_FEE = 3000;  // 1% = 1_0000

    function run() external deployer {
        // Confirm that we have our required contracts deployed
        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        StrategyRegistry strategyRegistry = StrategyRegistry(requireDeployment('StrategyRegistry'));

        // Deploy strategy strategies
        NFTXV3Strategy nftxV3Strategy = new NFTXV3Strategy();
        NFTXV3LiquidityStrategy nftxV3LiquidityStrategy = new NFTXV3LiquidityStrategy();

        // Approve our strategies
        strategyRegistry.approveStrategy(address(nftxV3Strategy), true);
        strategyRegistry.approveStrategy(address(nftxV3LiquidityStrategy), true);

        // Store our strategies deployment address
        storeDeployment('NFTXV3Strategy', address(nftxV3Strategy));
        storeDeployment('NFTXV3LiquidityStrategy', address(nftxV3LiquidityStrategy));
    }
}
