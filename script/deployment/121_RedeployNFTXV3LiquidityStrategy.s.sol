// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our strategies and factory contracts.
 */
contract RedeployNFTXV3LiquidityStrategy is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        StrategyRegistry strategyRegistry = StrategyRegistry(requireDeployment('StrategyRegistry'));

        // Disable our existing strategy
        // strategyRegistry.approveStrategy(0x17eA96bF8Cf53fC8A33249eF4571893196B513d8, false);

        // Deploy strategy strategy
        NFTXV3LiquidityStrategy nftxV3LiquidityStrategy = new NFTXV3LiquidityStrategy();

        // Approve our strategies
        strategyRegistry.approveStrategy(address(nftxV3LiquidityStrategy), true);

        // Store our strategy deployment address
        storeDeployment('NFTXV3LiquidityStrategy', address(nftxV3LiquidityStrategy));
    }
}
