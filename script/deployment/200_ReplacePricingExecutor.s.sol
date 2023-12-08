// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Shortened interface for contracts that as {EpochManaged}
 */
interface IEpochManaged {
    function setEpochManager(address) external;
}

/**
 * This script is used to replace the {PricingExecutor} contract. The primary reason for
 * this is to update the {WETH} reference within it and prevent a WETH:WETH pool being
 * checked to instead return 1:1.
 *
 * This _should_ only need to subsequently update the {RegisterSweepTrigger}.
 */
contract ReplacePricingExecutor is DeploymentScript {

    function run() external deployer {

        // Load and reference our live authority contracts
        IAuthorityControl authorityControl = IAuthorityControl(requireDeployment('AuthorityControl'));
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        // Load our {EpochManager}
        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

        // We first need to unlink our current {RegisterSweep} contract
        address registerSweep = requireDeployment('RegisterSweepTrigger');
        epochManager.setEpochEndTrigger(registerSweep, false);

        // Deploy our new {PricingExecutor}
        UniswapV3PricingExecutor pricingExecutor = new UniswapV3PricingExecutor(0xDD2dce9C403f93c10af1846543870D065419E70b, WETH);

        // Deploy our new {RegisterSweep} contract
        RegisterSweepTrigger newRegisterSweep = new RegisterSweepTrigger(
            requireDeployment('NewCollectionWars'),
            address(pricingExecutor),
            requireDeployment('StrategyFactory'),
            requireDeployment('Treasury'),
            requireDeployment('SweepWars')
        );

        // Update the registered trigger
        epochManager.setEpochEndTrigger(address(newRegisterSweep), true);

        // Register the {EpochManager} against the new sweep trigger
        IEpochManaged(address(newRegisterSweep)).setEpochManager(address(epochManager));

        // RegisterSweep needs a range of authorities
        authorityRegistry.grantRole(authorityControl.EPOCH_TRIGGER(), address(newRegisterSweep));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(newRegisterSweep));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(newRegisterSweep));

        // Update our JSON contracts
        storeDeployment('UniswapV3PricingExecutor', address(pricingExecutor));
        storeDeployment('RegisterSweepTrigger', address(registerSweep));

    }

}
