// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
// import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our strategies and vault factory contracts.
 */
contract DeployVaultContracts is DeploymentScript {

    function run() external deployer {

        // Confirm that we have our required contracts deployed
        address authorityControl = requireDeployment('AuthorityControl');
        address collectionRegistry = requireDeployment('CollectionRegistry');

        // Deploy vault strategies
        NFTXInventoryStakingStrategy inventoryStaking = new NFTXInventoryStakingStrategy();
        // RevenueStakingStrategy revenueStaking = new RevenueStakingStrategy();

        // Store our strategies deployment address
        storeDeployment('NFTXInventoryStakingStrategy', address(inventoryStaking));
        // storeDeployment('RevenueStakingStrategy', address(revenueStaking));

        // Deploy our vault factory
        StrategyFactory strategyFactory = new StrategyFactory(authorityControl, collectionRegistry);

        // Store our vault factory
        storeDeployment('StrategyFactory', address(strategyFactory));

    }

}
