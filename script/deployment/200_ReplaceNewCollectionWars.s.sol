// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 *
 */
contract ReplaceNewCollectionWars is DeploymentScript {

    EpochManager epochManager;
    FLOOR floor;
    NewCollectionWars newCollectionWars;
    VeFloorStaking staking;

    function run() external deployer {

        // Load and reference our live authority contracts
        IAuthorityControl authorityControl = IAuthorityControl(requireDeployment('AuthorityControl'));
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        epochManager = EpochManager(requireDeployment('EpochManager'));
        floor = FLOOR(requireDeployment('FloorToken'));
        staking = VeFloorStaking(requireDeployment('VeFloorStaking'));

        // Deploy our new {NewCollectionWars} contract
        newCollectionWars = new NewCollectionWars(
            requireDeployment('AuthorityControl'),
            requireDeployment('VeFloorStaking')
        );

        // Update the required contracts
        epochManager.setEpochEndTrigger(requireDeployment('RegisterSweepTrigger'), false);
        RegisterSweepTrigger registerSweep = new RegisterSweepTrigger(
            requireDeployment('NewCollectionWars'),
            requireDeployment('UniswapV3PricingExecutor'),
            requireDeployment('StrategyFactory'),
            requireDeployment('Treasury'),
            requireDeployment('SweepWars')
        );

        // Set our new register sweep end trigger
        epochManager.setEpochEndTrigger(address(registerSweep), true);

        // Assign the new collection war contract
        staking.setVotingContracts(address(newCollectionWars), requireDeployment('SweepWars'));
        epochManager.setContracts(address(newCollectionWars), address(0));

        // Set our epoch manager
        newCollectionWars.setEpochManager(address(epochManager));
        registerSweep.setEpochManager(address(epochManager));

        // RegisterSweep needs a range of authorities
        authorityRegistry.grantRole(authorityControl.EPOCH_TRIGGER(), address(registerSweep));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(registerSweep));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(registerSweep));

        storeDeployment('NewCollectionWars', address(newCollectionWars));
        storeDeployment('RegisterSweepTrigger', address(registerSweep));
    }

}
