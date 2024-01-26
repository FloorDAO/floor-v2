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
    /// The Sepolia address of the NFTX Router
    address internal constant NFTX_ROUTER = 0xD36ece08F76c50EC3F01db65BBc5Ef5Aa5fbE849;
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

        /*
        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('MILADY/WETH Full Range Liquidity'),
            address(nftxV3LiquidityStrategy),
            abi.encode(
                3, // vaultId
                NFTX_ROUTER, // router
                POOL_FEE,
                0,
                -887220,
                887220
            ),
            0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6
        );

        console.log(_strategyId);
        console.log(_strategy);

        // Deploy our strategy
        (_strategyId, _strategy) = strategyFactory.deployStrategy(
            bytes32('MILADY/WETH Inventory'),
            address(nftxV3Strategy),
            abi.encode(
                3,  // Milady Vault ID
                0xfBFf0635f7c5327FD138E1EBa72BD9877A6a7C1C  // INFTXInventoryStakingV3
            ),
            0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6
        );

        console.log(_strategyId);
        console.log(_strategy);

        // Deploy our strategy
        (_strategyId, _strategy) = strategyFactory.deployStrategy(
            bytes32('PUDGY/WETH Full Range Liquidity'),
            address(nftxV3LiquidityStrategy),
            abi.encode(
                6, // vaultId
                NFTX_ROUTER, // router
                POOL_FEE,
                0,
                -887220,
                887220
            ),
            0xa807e2a221C6dAAFE1b4A3ED2dA5E8A53fDAf6BE
        );

        console.log(_strategyId);
        console.log(_strategy);
        */

        // Store our strategies deployment address
        storeDeployment('NFTXV3Strategy', address(nftxV3Strategy));
        storeDeployment('NFTXV3LiquidityStrategy', address(nftxV3LiquidityStrategy));
    }
}
