// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our strategies and factory contracts.
 */
contract DeployStrategyContracts is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        address authorityControl = requireDeployment('AuthorityControl');
        address collectionRegistry = requireDeployment('CollectionRegistry');
        address treasury = requireDeployment('Treasury');

        // Deploy strategy strategies
        DistributedRevenueStakingStrategy distributedRevenueStakingStrategy = new DistributedRevenueStakingStrategy(address(authorityControl));
        NFTXInventoryStakingStrategy inventoryStaking = new NFTXInventoryStakingStrategy();
        NFTXLiquidityPoolStakingStrategy liquidityStaking = new NFTXLiquidityPoolStakingStrategy();
        RevenueStakingStrategy revenueStaking = new RevenueStakingStrategy();
        UniswapV3Strategy uniswapV3Staking = new UniswapV3Strategy();

        // Store our strategies deployment address
        storeDeployment('DistributedRevenueStakingStrategy', address(distributedRevenueStakingStrategy));
        storeDeployment('NFTXInventoryStakingStrategy', address(inventoryStaking));
        storeDeployment('NFTXLiquidityPoolStakingStrategy', address(liquidityStaking));
        storeDeployment('RevenueStakingStrategy', address(revenueStaking));
        storeDeployment('UniswapV3Strategy', address(uniswapV3Staking));

        // Deploy our strategy registry
        StrategyRegistry strategyRegistry = new StrategyRegistry(authorityControl);

        // Deploy our strategy factory
        StrategyFactory strategyFactory = new StrategyFactory(authorityControl, collectionRegistry, address(strategyRegistry));

        // Store our strategy factory
        storeDeployment('StrategyFactory', address(strategyFactory));

        // Set our {Treasury} against the {StrategyFactory}
        strategyFactory.setTreasury(treasury);
    }
}
