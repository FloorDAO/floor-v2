// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract DeployDistributedStrategy is DeploymentScript {

    function run() external deployer {

        address epochManager = requireDeployment('EpochManager');
        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        address implementation = requireDeployment('DistributedRevenueStakingStrategy');
        IWETH weth = IWETH(WETH);

        // Deploy our strategy
        (uint strategyId, address strategy) = strategyFactory.deployStrategy(
            'WETH Revenue',
            implementation,
            abi.encode(address(weth), 0.1 ether, epochManager),
            address(weth)
        );

        // Wrap an ETH into WETH
        weth.deposit{value: 1 ether}();

        // Deposit WETH into the strategy
        weth.approve(strategy, 1 ether);
        DistributedRevenueStakingStrategy(strategy).depositErc20(1 ether);

        console.log('WETH Revenue Distribution:');
        console.log(strategyId);
        console.log(strategy);
        console.log('---');

    }

}
