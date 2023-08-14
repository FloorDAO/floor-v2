// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from './mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from './mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from './mocks/erc/ERC1155Mock.sol';
import {PricingExecutorMock} from './mocks/PricingExecutor.sol';
import {SweeperMock} from './mocks/Sweeper.sol';

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {FloorNft} from '@floor/tokens/FloorNft.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {BaseStrategy} from '@floor/strategies/BaseStrategy.sol';
import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
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
    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    /// @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// Defines a test user
    address alice;

    /// Define an approved strategy and collection
    address approvedStrategy;
    address approvedCollection;

    /// Defines our sweeper addresses
    address manualSweeper;
    address sweeperMock;

    // Track our internal contract addresses
    FLOOR floor;
    VeFloorStaking veFloor;
    ERC20Mock erc20;
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
        epochManager.setContracts(address(newCollectionWars), address(0));

        // Set our epoch manager
        newCollectionWars.setEpochManager(address(epochManager));
        sweepWars.setEpochManager(address(epochManager));
        veFloor.setEpochManager(address(epochManager));
        treasury.setEpochManager(address(epochManager));

        // Update our veFloor staking receiver to be the {Treasury}
        veFloor.setFeeReceiver(address(treasury));

        // Set our war contracts on the veFloor staking contract
        veFloor.setVotingContracts(address(newCollectionWars), address(sweepWars));

        // Approve a strategy
        approvedStrategy = address(new NFTXInventoryStakingStrategy());

        // Approve a collection
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        collectionRegistry.approveCollection(approvedCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Set our manual sweeper and approve it for use
        manualSweeper = address(new ManualSweeper());
        treasury.approveSweeper(manualSweeper, true);

        // Set up our sweeper mock that will return tokens
        sweeperMock = address(new SweeperMock(address(treasury)));
        treasury.approveSweeper(sweeperMock, true);

        // Define our ERC20 token
        erc20 = new ERC20Mock();
    }

    function test_CanSetContracts() external {
        epochManager.setContracts(
            address(2), // newCollectionWars
            address(7) // voteMarket
        );

        assertEq(address(epochManager.newCollectionWars()), address(2));
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
        uint vaultCount = 10;
        uint stakerCount = 25;

        // Register our epoch end trigger that stores our treasury sweep
        RegisterSweepTrigger registerSweepTrigger = new RegisterSweepTrigger(
            address(newCollectionWars),
            address(pricingExecutorMock),
            address(strategyFactory),
            address(treasury),
            address(sweepWars)
        );

        registerSweepTrigger.setEpochManager(address(epochManager));
        epochManager.setEpochEndTrigger(address(registerSweepTrigger), true);

        // Assign required roles for our trigger and epoch manager contracts
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(registerSweepTrigger));
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), address(registerSweepTrigger));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(registerSweepTrigger));
        authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), address(epochManager));

        // Set our sample size of the GWV and to retain 50% of {Treasury} yield
        sweepWars.setSampleSize(5);

        // Mock our Voting mechanism to unlock unlimited user votes without backing and give
        // them a voting power of 1 ether.
        vm.mockCall(address(sweepWars), abi.encodeWithSelector(SweepWars.userVotesAvailable.selector), abi.encode(type(uint).max));
        vm.mockCall(address(veFloor), abi.encodeWithSelector(VeFloorStaking.votingPowerOfAt.selector), abi.encode(1 ether));

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

            // Each staker will then deposit and vote
            for (uint j; j < stakerCount; ++j) {
                // Cast votes from this user against the vault collection
                vm.startPrank(stakers[j]);
                sweepWars.vote(collection, 1 ether, false);
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

        // Since we have a manual sweep, we should have no ETH taken our of our {Treasury}
        uint startBalance = address(treasury).balance;

        // Sweep the epoch (won't actually sweep as it's manual, so it will just mark it
        // as complete).
        treasury.sweepEpoch(0, manualSweeper, 'Test sweep', 0);

        // Confirm that no ETH was spent
        assertEq(startBalance, address(treasury).balance);

        // Get our updated epoch information
        (sweepType, completed, message) = treasury.epochSweeps(epochManager.currentEpoch() - 1);

        // assertEq(sweepType, TreasuryEnums.SweepType.SWEEP);
        assertEq(completed, true);
        assertEq(message, 'Test sweep');
    }

    /**
     * When there are no FLOOR tokens in the sweep, then we shouldn't have any burn
     * mechanics triggered, nor the sweep triggered.
     */
    function test_NoFloorTokensReceivedInSweepDoesNotRaiseBurnErrors(uint startBalance) external {
        // Provide the {Treasury} with sufficient WETH to fulfil the sweep
        deal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, address(treasury), 15 ether);

        // Provide the {Treasury} with the starting FLOOR balance
        deal(address(floor), address(treasury), startBalance);

        // Set up our collections and amounts to just use the {ERC20Mock}
        address[] memory collections = new address[](2);
        collections[0] = address(erc20);
        collections[1] = address(erc20);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 10 ether;
        amounts[1] = 5 ether;

        // Register a sweep that does not include any FLOOR token amounts
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.SWEEP);
        setCurrentEpoch(address(epochManager), 1);

        // Sweep the epoch
        treasury.sweepEpoch(0, sweeperMock, 'Test sweep', 0);

        // Confirm that we still hold our starting balance and nothing has been burnt
        assertEq(floor.balanceOf(address(treasury)), startBalance);
    }

    /**
     * When FLOOR tokens are received in the sweep, we should burn any received, whilst
     * still maintaining any initially held balance.
     */
    function test_FloorTokensReceivedInSweepAreBurned(uint startBalance, uint sweepAmount) external {
        // Ensure that the combination of start balance and sweep amount won't exceed
        // the max uint value and overflow.
        vm.assume(startBalance < 10000 ether);
        vm.assume(sweepAmount < 10000 ether);

        // Provide the {Treasury} with sufficient WETH to fulfil the sweep and the
        // subsequent resweep.
        deal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, address(treasury), (10 ether + sweepAmount) * 2);

        // Provide the {Treasury} with the starting FLOOR balance
        deal(address(floor), address(treasury), startBalance);
        assertEq(floor.balanceOf(address(treasury)), startBalance);

        // Set up our collections and amounts to use {ERC20Mock} and {FLOOR} tokens
        address[] memory collections = new address[](2);
        collections[0] = address(erc20);
        collections[1] = address(floor);

        uint[] memory amounts = new uint[](2);
        amounts[0] = 10 ether;
        amounts[1] = sweepAmount;

        // Register a sweep that does not include any FLOOR token amounts
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.SWEEP);
        setCurrentEpoch(address(epochManager), 1);

        // Confirm that our event will be triggered in the sweep
        if (amounts[1] > 0) {
            vm.expectEmit(true, true, false, true, address(floor));
            emit Transfer(address(treasury), address(0), sweepAmount);
        }

        // Run our sweeper
        treasury.sweepEpoch(0, sweeperMock, 'Test sweep', 0);

        // Confirm that, due to the burn, we still have the same starting balance
        assertEq(floor.balanceOf(address(treasury)), startBalance);

        // Confirm that our event will be triggered in the resweep
        if (amounts[1] > 0) {
            vm.expectEmit(true, true, false, true, address(floor));
            emit Transfer(address(treasury), address(0), sweepAmount);
        }

        // Resweep the epoch using the sweeper mock again
        treasury.resweepEpoch(0, sweeperMock, 'Test sweep', 0);

        // Confirm that, due to the burn, we still have the same starting balance
        assertEq(floor.balanceOf(address(treasury)), startBalance);
    }

    /*
     * @dev To avoid needing a full integration test, this has just pulled out the
     * key logic.
     */
    function test_CanHandleDifferentSweepTokenDecimalAccuracy() public {
        // Hardcode the token ETH price as 1 ether
        uint tokenEthPrice = 1 ether;

        // Iterate over a range of decimal accuracies to test against and confirm that
        // they will each give the exepcted ETH value.
        for (uint8 i = 6; i <= 18; ++i) {
            ERC20Mock erc20Mock = new ERC20Mock();
            erc20Mock.setDecimals(i);

            // Find the ETH rewards based on the amount of token that is
            // decimal accurate.
            uint ethRewards = tokenEthPrice * (10 * (10 ** erc20Mock.decimals())) / (10 ** erc20Mock.decimals());

            // We need to now confirm that the ETH rewards are the same for each. The
            // equivalent of 10 tokens valued at 1 eth each.
            assertEq(ethRewards, 10 ether);
        }
    }

    function test_CanSetAndDeleteEpochEndTriggers(uint8 _delete) external {
        // Set up epoch end triggers
        uint expectedTriggers = type(uint8).max;

        // Create address 0 - 255 (this means 256 in total as 0 is included)
        for (uint160 i; i <= expectedTriggers; i++) {
            epochManager.setEpochEndTrigger(address(i), true);
            emit log_address(address(i));
        }

        emit log_uint(epochManager.epochEndTriggers().length);

        // Now try to delete a trigger against the generated number
        epochManager.setEpochEndTrigger(address(uint160(_delete)), false);

        // We should be able to confirm that the trigger has been deleted and that the
        // length is as expected.
        address[] memory triggers = epochManager.epochEndTriggers();
        assertEq(triggers.length, 255);

        // Loop through the remaining triggers and confirm we no longer have the
        // deleted index.
        for (uint160 i; i < triggers.length; i++) {
            assertFalse(triggers[i] == address(uint160(_delete)));
        }
    }
}
