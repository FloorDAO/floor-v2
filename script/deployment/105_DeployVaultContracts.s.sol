// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';

import {VaultFactory} from '@floor/vaults/VaultFactory.sol';

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
        NFTXInventoryStakingStrategy inventoryStaking = new NFTXInventoryStakingStrategy('NFTX Inventory Staking');
        RevenueStakingStrategy revenueStaking = new RevenueStakingStrategy('Revenue Staking');

        // Store our strategies deployment address
        storeDeployment('NFTXInventoryStakingStrategy', address(inventoryStaking));
        storeDeployment('RevenueStakingStrategy', address(revenueStaking));

        // Deploy our vault factory
        VaultFactory vaultFactory = new VaultFactory(authorityControl, collectionRegistry);

        // Store our vault factory
        storeDeployment('VaultFactory', address(vaultFactory));

    }

}
