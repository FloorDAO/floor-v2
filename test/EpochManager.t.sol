// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import {ERC721Mock} from './mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from './mocks/erc/ERC1155Mock.sol';
import {PricingExecutorMock} from './mocks/PricingExecutor.sol';

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {FloorNft} from '@floor/tokens/FloorNft.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {BaseStrategy} from '@floor/strategies/BaseStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager, EpochTimelocked, NoPricingExecutorSet} from '@floor/EpochManager.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, Treasury} from '@floor/Treasury.sol';

import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {FloorTest} from './utilities/Environments.sol';

contract EpochManagerTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    address alice;

    address approvedStrategy;
    address approvedCollection;

    address manualSweeper;

    // Track our internal contract addresses
    FLOOR floor;
    VeFloorStaking veFloor;
    ERC20Mock erc20;
    ERC721Mock erc721;
    ERC1155Mock erc1155;
    CollectionRegistry collectionRegistry;
    EpochManager epochManager;
    FloorNft floorNft;
    Treasury treasury;
    PricingExecutorMock pricingExecutorMock;
    NewCollectionWars newCollectionWars;
    SweepWars sweepWars;
    StrategyFactory strategyFactory;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Create our test users
        alice = users[0];

        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new VeFloorStaking(floor, address(this));

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry)
        );

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(floor),
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );

        // Create our Gauge Weight Vote contract
        sweepWars = new SweepWars(
            address(collectionRegistry),
            address(strategyFactory),
            address(veFloor),
            address(authorityRegistry),
            address(treasury)
        );

        // Create our Floor NFT
        floorNft = new FloorNft(
            'Floor NFT',  // _name
            'nftFloor',   // _symbol
            250,          // _maxSupply
            5             // _maxMintAmountPerTx
        );

        // Create our {NewCollectionWars} contract
        newCollectionWars = new NewCollectionWars(address(authorityRegistry), address(veFloor));

        epochManager = new EpochManager();
        epochManager.setContracts(
            address(collectionRegistry),
            address(newCollectionWars),
            address(pricingExecutorMock),
            address(treasury),
            address(strategyFactory),
            address(sweepWars),
            address(0)
        );

        // Set our epoch manager
        newCollectionWars.setEpochManager(address(epochManager));
        sweepWars.setEpochManager(address(epochManager));
        treasury.setEpochManager(address(epochManager));

        // Update our veFloor staking receiver to be the {Treasury}
        veFloor.setFeeReceiver(address(treasury));

        // Approve a strategy
        approvedStrategy = address(new NFTXInventoryStakingStrategy());

        // Approve a collection
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        collectionRegistry.approveCollection(approvedCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Set our manual sweeper
        manualSweeper = address(new ManualSweeper());

        // Give our epoch manager permission to take a strategy factory snapshot
        authorityRegistry.grantRole(authorityControl.VAULT_MANAGER(), address(epochManager));
    }

    /**
     * ..
     */
    function test_CanSetCurrentEpoch(uint epoch) external {
        // Confirm we have a default epoch of zero
        assertEq(epochManager.currentEpoch(), 0);

        // Set our epoch and confirm that it has changed correctly
        epochManager.setCurrentEpoch(epoch);
        assertEq(epochManager.currentEpoch(), epoch);
    }

    /**
     * ..
     */
    function test_CannotSetCurrentEpochWithoutPermission() external {
        vm.expectRevert('Ownable: caller is not the owner');
        vm.prank(alice);
        epochManager.setCurrentEpoch(3);
    }

    /**
     * ..
     */
    function test_CanSetContracts() external {
        epochManager.setContracts(
            address(1), // collectionRegistry
            address(2), // newCollectionWars
            address(3), // pricingExecutor
            address(4), // treasury
            address(5), // strategyFactory
            address(6), // voteContract,
            address(7) // voteMarket
        );

        assertEq(address(epochManager.collectionRegistry()), address(1));
        assertEq(address(epochManager.newCollectionWars()), address(2));
        assertEq(address(epochManager.pricingExecutor()), address(3));
        assertEq(address(epochManager.treasury()), address(4));
        assertEq(address(epochManager.strategyFactory()), address(5));
        assertEq(address(epochManager.voteContract()), address(6));
        assertEq(address(epochManager.voteMarket()), address(7));
    }

    function test_CanScheduleCollectionAdditionEpoch(uint epoch) external {
        // Prevents overflow of `epoch + 1`
        vm.assume(epoch < type(uint).max);

        assertFalse(epochManager.isCollectionAdditionEpoch(epoch));

        vm.prank(address(newCollectionWars));
        epochManager.scheduleCollectionAddtionEpoch(epoch, 1);

        assertTrue(epochManager.isCollectionAdditionEpoch(epoch));

        assertFalse(epochManager.isCollectionAdditionEpoch(epoch + 1));
    }

    function test_CanEndEpoch() public {
        assertEq(epochManager.lastEpoch(), 0);
        assertEq(epochManager.currentEpoch(), 0);

        // Trigger our epoch end
        epochManager.endEpoch();

        assertEq(epochManager.lastEpoch(), block.timestamp);
        assertEq(epochManager.currentEpoch(), 1);
    }

    /**
     * After an epoch has run, there is a minimum wait that must be respected before
     * trying to run it again. If this is not catered for, then we expect a revert.
     */
    function test_CannotCallAnotherEpochWithoutRespectingTimeout() public {
        // Mock our StrategyFactory call to return no vaults
        vm.mockCall(address(strategyFactory), abi.encodeWithSelector(StrategyFactory.strategies.selector), abi.encode(new address[](0)));

        // Call an initial trigger, which should pass as no vaults or staked users
        // are set up for the test.
        epochManager.endEpoch();

        // Calling the epoch again should result in a reversion as we have not
        // respected the enforced timelock.
        vm.expectRevert(abi.encodeWithSelector(EpochTimelocked.selector, block.timestamp + 7 days));
        epochManager.endEpoch();

        // After moving forwards 7 days, we can now successfully end another epoch
        vm.warp(block.timestamp + 7 days);
        epochManager.endEpoch();
    }

    function test_CanHandleEpochStressTest() public {
        uint vaultCount = 20;
        uint stakerCount = 100;

        // Set our sample size of the GWV and to retain 50% of {Treasury} yield
        sweepWars.setSampleSize(5);

        // Prevent the {StrategyFactory} from trying to transfer tokens when registering the mint
        // vm.mockCall(address(strategyFactory), abi.encodeWithSelector(StrategyFactory.registerMint.selector), abi.encode(''));

        // Mock our Voting mechanism to unlock unlimited user votes without backing
        vm.mockCall(address(sweepWars), abi.encodeWithSelector(SweepWars.userVotesAvailable.selector), abi.encode(type(uint).max));

        // Mock our vaults response (our {StrategyFactory} has a hardcoded address(8) when we
        // set up the {Treasury} contract).
        address[] memory vaults = new address[](vaultCount);
        address payable[] memory stakers = utilities.createUsers(stakerCount);

        // Loop through our mocked vaults to mint tokens
        for (uint i; i < vaultCount; ++i) {
            // Approve a unique collection
            address collection = address(uint160(uint(vaultCount + i)));
            collectionRegistry.approveCollection(collection, SUFFICIENT_LIQUIDITY_COLLECTION);

            // Deploy our vault
            (, vaults[i]) = strategyFactory.deployStrategy('Test Vault', approvedStrategy, _strategyInitBytes(), collection);

            address[] memory tokens = new address[](1);
            tokens[0] = collection;
            uint[] memory amounts = new uint[](1);
            amounts[0] = 1 ether;

            // Set up a mock that will set rewards to be a static amount of ether
            // TODO: ..

            // Each staker will then deposit and vote
            for (uint j; j < stakerCount; ++j) {
                // Cast votes from this user against the vault collection
                vm.startPrank(stakers[i]);
                sweepWars.vote(collection, 1 ether);
                vm.stopPrank();
            }
        }

        // Set our block to a specific one
        vm.roll(12);

        // Trigger our epoch end and pray to the gas gods
        epochManager.endEpoch();

        // We can now confirm the distribution of ETH going to the top collections by
        // querying the `epochSweeps` of the epoch iteration. The arrays in the struct
        // are not included in read attempts as we cannot get the information accurately.
        // The epoch will have incremented in `endEpoch`, so we minus 1.
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epochManager.currentEpoch() - 1);

        // assertEq(sweepType, TreasuryEnums.SweepType.SWEEP);
        assertEq(completed, false);
        assertEq(message, '');

        vm.roll(23);

        // Move some funds to the Treasury
        deal(address(treasury), 1000 ether);

        // Sweep the epoch (won't actually sweep as it's manual, so it will just mark it
        // as complete).
        treasury.sweepEpoch(0, manualSweeper, 'Test sweep', 0);

        // Get our updated epoch information
        (sweepType, completed, message) = treasury.epochSweeps(epochManager.currentEpoch() - 1);

        // assertEq(sweepType, TreasuryEnums.SweepType.SWEEP);
        assertEq(completed, true);
        assertEq(message, 'Test sweep');
    }
}
