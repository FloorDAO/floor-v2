// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {AuthorityRegistry} from '@floor/authorities/AuthorityRegistry.sol';
import {MigrateTreasury} from '@floor/migrations/MigrateTreasury.sol';
import {VestingClaim} from '@floor/migrations/VestingClaim.sol';
import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';
import {LiquidateNegativeCollectionTrigger} from '@floor/triggers/LiquidateNegativeCollection.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 */
contract ReplaceTreasury is DeploymentScript {

    function run() external deployer {

        address floorToken = requireDeployment('FloorToken');
        address newCollectionWars = requireDeployment('NewCollectionWars');
        address pricingExecutor = requireDeployment('UniswapV3PricingExecutor');

        AuthorityControl authorityControl = AuthorityControl(requireDeployment('AuthorityControl'));
        AuthorityRegistry authorityRegistry = AuthorityRegistry(requireDeployment('AuthorityRegistry'));
        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        VeFloorStaking veFloorStaking = VeFloorStaking(requireDeployment('VeFloorStaking'));

        // Deploy our new {Treasury} contract
        Treasury treasury = new Treasury(address(authorityControl), floorToken, DEPLOYMENT_WETH);

        // Set our new {Treasury} against the {StrategyFactory}
        strategyFactory.setTreasury(address(treasury));

        // Set our {VeFloorStaking} contract
        Treasury(treasury).setVeFloorStaking(address(veFloorStaking));
        Treasury(treasury).setStrategyFactory(address(strategyFactory));

        // We will need to deploy a new {SweepWars} contract to assign the new {Treasury}
        SweepWars sweepWars = new SweepWars(
            requireDeployment('CollectionRegistry'),  // address _collectionRegistry
            address(strategyFactory),                 // address _strategyFactory
            address(veFloorStaking),                  // address _veFloor
            address(authorityControl),                // address _authority
            address(treasury)                         // address _treasury
        );


        // Update our vefloor staking contract references
        veFloorStaking.setVotingContracts(newCollectionWars, address(sweepWars));

        // Set our {EpochManager} in the new {Treasury}
        Treasury(treasury).setEpochManager(address(epochManager));

        // We will need to deploy a new {RegisterSweepTrigger} to update the {Treasury} and
        // {SweepWars} contract.
        RegisterSweepTrigger registerSweep = new RegisterSweepTrigger(
            newCollectionWars,
            pricingExecutor,
            address(strategyFactory),
            address(treasury),
            address(sweepWars)
        );

        // When we have deployed our new sweep trigger, we need to assign it to our
        // {EpochManager} and replace the existing one. We then update the registered
        // address for {RegisterSweepTrigger}.
        epochManager.setEpochEndTrigger(requireDeployment('RegisterSweepTrigger'), false);
        epochManager.setEpochEndTrigger(address(registerSweep), true);
        registerSweep.setEpochManager(address(epochManager));

        // RegisterSweep needs a range of authorities
        authorityRegistry.grantRole(authorityControl.EPOCH_TRIGGER(), address(registerSweep));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(registerSweep));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(registerSweep));

        StoreEpochCollectionVotesTrigger storeEpochVotes = new StoreEpochCollectionVotesTrigger(address(sweepWars));
        epochManager.setEpochEndTrigger(requireDeployment('StoreEpochCollectionVotesTrigger'), false);
        epochManager.setEpochEndTrigger(address(storeEpochVotes), true);
        storeEpochVotes.setEpochManager(address(epochManager));

        // Register a {DistributedRevenueStakingStrategy} strategy so that we can deploy a
        // {LiquidateNegativeCollectionTrigger}.
        (, address _strategy) = strategyFactory.deployStrategy(
            bytes32('Liquidation Pool'),
            requireDeployment('DistributedRevenueStakingStrategy'),
            abi.encode(DEPLOYMENT_WETH, 10 ether, address(epochManager)),
            DEPLOYMENT_WETH
        );

        LiquidateNegativeCollectionTrigger liquidateNegativeCollectionTrigger = new LiquidateNegativeCollectionTrigger(
            pricingExecutor,
            address(sweepWars),
            address(strategyFactory),
            _strategy,
            0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD, // Uniswap Universal Router
            DEPLOYMENT_WETH
        );

        // Register our epoch trigger
        epochManager.setEpochEndTrigger(requireDeployment('LiquidateNegativeCollectionTrigger'), false);
        epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionTrigger), true);

        liquidateNegativeCollectionTrigger.setEpochManager(address(epochManager));

        // Deploy our updated migration contracts
        MigrateTreasury migrateTreasury = new MigrateTreasury(0x91E453f442d25523F42063E1695390e325076ca2, address(treasury));

        VestingClaim vestingClaim = new VestingClaim(floorToken, DEPLOYMENT_WETH, address(treasury));

        // Grant our new {Treasury} roles
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(vestingClaim));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(treasury));

        // Update the {Treasury} in the {StrategyFactory}
        strategyFactory.setTreasury(address(treasury));

        storeDeployment('RegisterSweepTrigger', address(registerSweep));
        storeDeployment('StoreEpochCollectionVotesTrigger', address(storeEpochVotes));
        storeDeployment('LiquidateNegativeCollectionTrigger', address(liquidateNegativeCollectionTrigger));
        storeDeployment('Treasury', address(treasury));
        storeDeployment('SweepWars', address(sweepWars));
        storeDeployment('MigrateTreasury', address(migrateTreasury));
        storeDeployment('VestingClaim', address(vestingClaim));

    }

}
