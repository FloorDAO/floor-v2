// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract ReplaceNFTXV3LiquidityStrategyAndFund is DeploymentScript {

    /// The Sepolia address of the NFTX Router
    address internal constant NFTX_ROUTER = 0xD36ece08F76c50EC3F01db65BBc5Ef5Aa5fbE849;
    uint24 internal constant POOL_FEE = 3000;  // 1% = 1_0000

    function run() external deployer {

        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        StrategyRegistry strategyRegistry = StrategyRegistry(requireDeployment('StrategyRegistry'));
        address liquidityImplementation = requireDeployment('NFTXV3LiquidityStrategy');

        // Withdraw 100% of position from strategy 4 and 5
        strategyFactory.withdrawPercentage(strategyFactory.strategy(4), 100_00);
        strategyFactory.withdrawPercentage(strategyFactory.strategy(5), 100_00);

        // Deactivate existing liquidity strategies for NFTX V3 (4 and 5)
        strategyFactory.bypassStrategy(strategyFactory.strategy(4), true);
        strategyFactory.bypassStrategy(strategyFactory.strategy(5), true);

        // Deploy new strategy contract
        address newLiquidityImplementation = address(new NFTXV3LiquidityStrategy());

        // Disable old contract implementation from StrategyRegistry
        strategyRegistry.approveStrategy(liquidityImplementation, false);

        // Add new contract implementation to StrategyRegistry
        strategyRegistry.approveStrategy(newLiquidityImplementation, true);

        // Create 2x Strategies for MILADY and PUDGY
        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('MILADY/WETH Full Range Liquidity'),
            address(newLiquidityImplementation),
            abi.encode(
                3, // vaultId
                NFTX_ROUTER, // router
                POOL_FEE,
                0,
                -887220,
                887220
            ),
            0x67523B71Bc3eeF7E5d90492aeD7a4B447Bc1deCd
        );

        console.log('MILADY/WETH Full Range Liquidity');
        console.log(_strategyId);
        console.log(_strategy);

        // MILADY LIQUIDITY
        NFTXV3LiquidityStrategy strategy = NFTXV3LiquidityStrategy(payable(_strategy));
        console.log(strategy.vToken().balanceOf(address(this)));
        console.log(payable(address(this)).balance);
        strategy.vToken().approve(address(strategy), type(uint).max);
        strategy.deposit{value: 237310002395997562}({
            vTokenDesired: 43239304373879663253,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });

        // Deploy our strategy
        (_strategyId, _strategy) = strategyFactory.deployStrategy(
            bytes32('PUDGY/WETH Full Range Liquidity'),
            address(newLiquidityImplementation),
            abi.encode(
                6, // vaultId
                NFTX_ROUTER, // router
                POOL_FEE,
                0,
                -887220,
                887220
            ),
            0x67523B71Bc3eeF7E5d90492aeD7a4B447Bc1deCd
        );

        console.log('PUDGY/WETH Full Range Liquidity');
        console.log(_strategyId);
        console.log(_strategy);

        // PUDGY LIQUIDITY
        strategy = NFTXV3LiquidityStrategy(payable(_strategy));
        console.log(strategy.vToken().balanceOf(address(this)));
        console.log(payable(address(this)).balance);
        strategy.vToken().approve(address(strategy), type(uint).max);
        strategy.deposit{value: 4201054236939019502}({
            vTokenDesired: 5379051444779240776,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });

        // Store our strategies deployment address
        storeDeployment('NFTXV3LiquidityStrategy', address(newLiquidityImplementation));

    }

}
