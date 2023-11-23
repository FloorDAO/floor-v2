// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

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

    address collectionOne   = 0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7;
    address collectionTwo   = 0x4dB1E9Aa44cd6a8F01d13D286149AE7664e3131F;
    address collectionThree = 0xB56061B12CD9F97918ac4AF319f17AEd4d7FB13b;

    EpochManager epochManager;
    FLOOR floor;
    NewCollectionWars newCollectionWars;
    VeFloorStaking staking;

    function run() external deployer {

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

        epochManager.setEpochEndTrigger(address(registerSweep), true);

        staking.setVotingContracts(address(newCollectionWars), requireDeployment('SweepWars'));
        epochManager.setContracts(address(newCollectionWars), address(0));
        newCollectionWars.setEpochManager(address(epochManager));

        storeDeployment('NewCollectionWars', address(newCollectionWars));
        storeDeployment('RegisterSweepTrigger', address(registerSweep));
    }

}
