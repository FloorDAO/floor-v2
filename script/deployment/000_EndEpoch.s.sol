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

        NewCollectionWars ncw = NewCollectionWars(requireDeployment('NewCollectionWars'));
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(1);

        console.log(uint8(sweepType));
        console.log(completed);
        console.log(message);

        console.log(ncw.floorWarWinner(0));
        console.log(ncw.floorWarWinner(1));

        // EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        // epochManager.endEpoch();
    }

}
