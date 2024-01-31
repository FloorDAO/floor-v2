// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our collection registry and approves our default collections.
 */
contract DisableStrategy is DeploymentScript {
    function run() external deployer {
        // Load and cast our Collection Registry
        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));

        // Remove legacy UV3 strategies
        strategyFactory.bypassStrategy(0x1Bf6971a603B389B5dAa37fe6c700A0a1AE77228, true);  // token id : 7608
        strategyFactory.bypassStrategy(0xeA2089C94FB4183A6ca73f6f858dbE1976059374, true);  // token id : 7813

        // Remove our old implementation
        StrategyRegistry strategyRegistry = StrategyRegistry(requireDeployment('StrategyRegistry'));
        strategyRegistry.approveStrategy(requireDeployment('UniswapV3Strategy'), false);

        // Deploy and store the new implementation
        UniswapV3Strategy uniswapV3Staking = new UniswapV3Strategy();
        strategyRegistry.approveStrategy(address(uniswapV3Staking), true);
        storeDeployment('UniswapV3Strategy', address(uniswapV3Staking));
    }
}
