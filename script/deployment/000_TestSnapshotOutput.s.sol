// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from '../../test/mocks/erc/ERC1155Mock.sol';

import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {LiquidateNegativeCollectionTrigger} from '@floor/triggers/LiquidateNegativeCollection.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {AuthorityRegistry} from '@floor/authorities/AuthorityRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {SendEth} from '@floor/actions/utils/SendEth.sol';
import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {Treasury} from '@floor/Treasury.sol';

import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Shows what the output of a snapshot would be.
 */
contract TestSnapshotOutput is DeploymentScript {

    function run() external deployer {

        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        (
            address[] memory strategies_,
            uint[] memory amounts_,
            uint totalAmount_
        ) = strategyFactory.snapshot(1);

        console.log('Total Amount of WETH:');
        console.log(totalAmount_);

        console.log('---');

        for (uint i; i < strategies_.length; ++i) {
            console.log(strategies_[i]);
            console.log(amounts_[i]);
        }

        revert('Do not commit this save.');

    }

}
