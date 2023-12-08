// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {EpochManager} from '@floor/EpochManager.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {AuthorityRegistry} from '@floor/authorities/AuthorityRegistry.sol';
import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';
import {LiquidateNegativeCollectionTrigger} from '@floor/triggers/LiquidateNegativeCollection.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';

import {Treasury} from '@floor/Treasury.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Ends the current epoch.
 */
contract EndEpoch is DeploymentScript {

    function run() external deployer {

        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        epochManager.endEpoch();
    }

}
