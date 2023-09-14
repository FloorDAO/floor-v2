// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {stdStorage, StdStorage, Test} from 'forge-std/Test.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

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
import {CannotSetNullAddress, Treasury} from '@floor/Treasury.sol';

import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {IEpochEndTriggered} from '@floor-interfaces/utils/EpochEndTriggered.sol';
import {TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {FoundryRandom} from "foundry-random/FoundryRandom.sol";

import {FloorTest} from './utilities/Environments.sol';

contract EpochManagerTest is FloorTest, FoundryRandom {
    using stdStorage for StdStorage;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_616_037;

    /// @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @dev Emitted when a sweep is registered
    event SweepRegistered(uint sweepEpoch, TreasuryEnums.SweepType sweepType, address[] collections, uint[] amounts);

    /// @dev When an epoch is swept
    event EpochSwept(uint epochIndex);

    /// Define a WETH constant
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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
            WETH
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
        uint maxStakerCount = 30;

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

        // Set our sample size of the GWV to allow the top 5 collections to receive a share
        sweepWars.setSampleSize(5);

        // Mock our Voting mechanism to unlock unlimited user votes without backing and give
        // them a voting power of 1 ether.
        vm.mockCall(address(sweepWars), abi.encodeWithSelector(SweepWars.userVotesAvailable.selector), abi.encode(type(uint).max));
        vm.mockCall(address(veFloor), abi.encodeWithSelector(VeFloorStaking.votingPowerOf.selector), abi.encode(100 ether));

        // Mock our vaults response (our {StrategyFactory} has a hardcoded address(8) when we
        // set up the {Treasury} contract).
        address[] memory vaults = new address[](vaultCount);
        address payable[] memory stakers = utilities.createUsers(maxStakerCount);

        // Keep a linear track ID so that we can have the same token output from multiple
        // strategies
        uint tracker = 1;

        // Loop through our mocked vaults to mint tokens
        for (uint i; i < vaultCount; ++i) {
            // Approve a unique collection
            address collection = address(uint160(i + 5));
            collectionRegistry.approveCollection(collection, SUFFICIENT_LIQUIDITY_COLLECTION);

            // Deploy our strategy
            (, vaults[i]) = strategyFactory.deployStrategy('Test Vault', approvedStrategy, _strategyInitBytes(), collection);

            // Generate a number of yield tokens between 1 and 5
            uint maxTokens = (tracker % 5) + 1;

            // Register our token and amount arrays
            address[] memory _tokens = new address[](maxTokens);
            uint[] memory _amounts = new uint[](maxTokens);

            // Loop through our max token limit
            for (uint t; t < maxTokens; ++t) {
                // Create a fake token and award it a yield value. This will allow some
                // collection tokens to be offset against the yield as the strategy collection
                // address will match tokens when it crosses over. The strategy collection
                // addresses start at 5 and increment from there. This means that tokens with
                // the address of 5 and 6 will offset against themselves.
                _tokens[t] = address(uint160((tracker % 6) + 1));
                _amounts[t] = (tracker % 20) * 1 ether;

                // We additionally need to mock the decimal count returned against a token. We
                // could, instead, create an ERC20 mock here but that would require our pricing
                // executor to be mocked instead. This seemed like a simpler approach.
                vm.mockCall(
                    _tokens[t],
                    abi.encodeWithSelector(ERC20.decimals.selector),
                    abi.encode(uint(18))
                );

                ++tracker;
            }

            // Mock our tokens and amounts to be returned in the snapshot
            vm.mockCall(
                vaults[i],
                abi.encodeWithSelector(BaseStrategy.snapshot.selector),
                abi.encode(_tokens, _amounts)
            );

            // Each staker will then deposit and vote
            for (uint j; j < tracker % 8; ++j) {
                // Cast votes from this user for the vault collection
                vm.prank(stakers[j]);
                sweepWars.vote(collection, int(((tracker % 10) + 1) * 1 ether));
            }
        }

        // Set our block to a specific one
        vm.roll(12);

        // Set our expected sweep collections. These should be in vote order desc.
        address[] memory expectedCollections = new address[](5);
        expectedCollections[0] = 0x0000000000000000000000000000000000000006;
        expectedCollections[1] = 0x000000000000000000000000000000000000000d;
        expectedCollections[2] = 0x000000000000000000000000000000000000000E;
        expectedCollections[3] = 0x0000000000000000000000000000000000000009;
        expectedCollections[4] = 0x0000000000000000000000000000000000000005;

        uint[] memory expectedAmounts = new uint[](5);
        expectedAmounts[0] = 67200000000000000000;
        expectedAmounts[1] = 141600000000000000000;
        expectedAmounts[2] = 121371428571428571024;
        expectedAmounts[3] = 101142857142857142756;
        expectedAmounts[4] = 0;

        // Confirm that we receive the expect event emit when the sweep is registered
        vm.expectEmit(true, true, false, true, address(treasury));
        emit SweepRegistered({
            sweepEpoch: 0,
            sweepType: TreasuryEnums.SweepType.SWEEP,
            collections: expectedCollections,
            amounts: expectedAmounts
        });

        // Trigger our epoch end and pray to the gas gods
        epochManager.endEpoch();

        // We can now confirm the distribution of ETH going to the top collections by
        // querying the `epochSweeps` of the epoch iteration. The arrays in the struct
        // are not included in read attempts as we cannot get the information accurately.
        // The epoch will have incremented in `endEpoch`, so we minus 1.
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epochManager.currentEpoch() - 1);

        assertTrue(sweepType == TreasuryEnums.SweepType.SWEEP);
        assertEq(completed, false);
        assertEq(message, '');

        vm.roll(23);

        // Give the Treasury both WETH and ETH, so that the initial ETH will be used and
        // topped up with withdrawn WETH.
        deal(address(treasury), 250 ether);
        deal(WETH, address(treasury), 250 ether);

        // Confirm our starting balances of both ETH and WETH tokens
        assertEq(address(treasury).balance, 250 ether);
        assertEq(ERC20(WETH).balanceOf(address(treasury)), 250 ether);

        vm.expectEmit(true, true, false, true, address(treasury));
        emit EpochSwept(0);

        // Sweep the epoch (won't actually sweep as it's manual, so it will just mark it
        // as complete).
        treasury.sweepEpoch(0, manualSweeper, 'Test sweep', 0);

        /**
         * Confirm that the ETH initially held was spent, and that additional WETH was
         * unwrapped to cover the additional requirement.
         *
         * The amount of ETH allocated to the sweep is: 431_314285714285713780
         *
         * With the manual sweep, the ETH sent to the sweeper is sent back to the caller,
         * which in this case is the {Treasury}.
         *
         * With the amount of ETH in the {Treasury} to being with being 250 ether, this will
         * leave a remaining amount of WETH to be unwrapped: 181_314285714285713780.
         *
         * So with this in mind, we should expect 250 - 181~ as the remaining WETH balance,
         * and 250 + (250 - 181~) as the remaining ETH balance.
         */

        assertEq(address(treasury).balance, 431_314285714285713780);
        assertEq(ERC20(WETH).balanceOf(address(treasury)), 68_685714285714286220);

        // We can then confirm that the sum of these two balances is the same as our original
        // ETH + WETH balance (500 ether).
        assertEq(address(treasury).balance + ERC20(WETH).balanceOf(address(treasury)), 500 ether);

        // Get our updated epoch information
        (sweepType, completed, message) = treasury.epochSweeps(epochManager.currentEpoch() - 1);

        assertTrue(sweepType == TreasuryEnums.SweepType.SWEEP);
        assertEq(completed, true);
        assertEq(message, 'Test sweep');

        // We would ideally confirm that our {Treasury} holds the expected tokens after the
        // sweep. This cannot be done with this version of the {ManualSweeper}, but sweeper
        // logic is tested separately.
    }

    /**
     * When there are no FLOOR tokens in the sweep, then we shouldn't have any burn
     * mechanics triggered, nor the sweep triggered.
     */
    function test_NoFloorTokensReceivedInSweepDoesNotRaiseBurnErrors(uint startBalance) external {
        // Provide the {Treasury} with sufficient WETH to fulfil the sweep
        deal(WETH, address(treasury), 15 ether);

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
        deal(WETH, address(treasury), (10 ether + sweepAmount) * 2);

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
        // Ensure that we don't try to delete a NULL address that would not exist
        vm.assume(_delete > 0);

        // Set up epoch end triggers
        uint expectedTriggers = type(uint8).max;

        // Create address 0 - 255 (this means 256 in total as 0 is included)
        for (uint160 i = 1; i <= expectedTriggers; i++) {
            epochManager.setEpochEndTrigger(address(i), true);
        }

        // Now try to delete a trigger against the generated number
        epochManager.setEpochEndTrigger(address(uint160(_delete)), false);

        // We should be able to confirm that the trigger has been deleted and that the
        // length is as expected.
        address[] memory triggers = epochManager.epochEndTriggers();
        assertEq(triggers.length, 254);

        // Loop through the remaining triggers and confirm we no longer have the
        // deleted index.
        for (uint160 i = 1; i < triggers.length; i++) {
            assertFalse(triggers[i] == address(uint160(_delete)));
        }
    }

    function test_CanGetEpochLength() external {
        assertEq(epochManager.EPOCH_LENGTH(), 7 days);
    }

    function test_CanGetEpochIterationTimestamp() external {
        // Set our epoch ahead of our test epochs
        setCurrentEpoch(address(epochManager), 10);

        // Write our last epoch timestamp
        stdstore.target(address(epochManager)).sig('lastEpoch()').checked_write(1692572869);

        // Test a range of times
        assertEq(epochManager.epochIterationTimestamp(1), 1692572869 - 63 days);
        assertEq(epochManager.epochIterationTimestamp(2), 1692572869 - 56 days);
        assertEq(epochManager.epochIterationTimestamp(5), 1692572869 - 35 days);
        assertEq(epochManager.epochIterationTimestamp(9), 1692572869 - 7 days);

        assertEq(epochManager.epochIterationTimestamp(10), 1692572869);

        assertEq(epochManager.epochIterationTimestamp(11), 1692572869 + 7 days);
        assertEq(epochManager.epochIterationTimestamp(12), 1692572869 + 14 days);
        assertEq(epochManager.epochIterationTimestamp(15), 1692572869 + 35 days);
        assertEq(epochManager.epochIterationTimestamp(19), 1692572869 + 63 days);

        // Update our last epoch timestamp
        stdstore.target(address(epochManager)).sig('lastEpoch()').checked_write(1692531530);

        // Test a range of times to show they are reflected
        assertEq(epochManager.epochIterationTimestamp(1), 1692531530 - 63 days);
        assertEq(epochManager.epochIterationTimestamp(2), 1692531530 - 56 days);
        assertEq(epochManager.epochIterationTimestamp(5), 1692531530 - 35 days);
        assertEq(epochManager.epochIterationTimestamp(9), 1692531530 - 7 days);

        assertEq(epochManager.epochIterationTimestamp(10), 1692531530);

        assertEq(epochManager.epochIterationTimestamp(11), 1692531530 + 7 days);
        assertEq(epochManager.epochIterationTimestamp(12), 1692531530 + 14 days);
        assertEq(epochManager.epochIterationTimestamp(15), 1692531530 + 35 days);
        assertEq(epochManager.epochIterationTimestamp(19), 1692531530 + 63 days);
    }

    function test_CannotSetNullEpochEndTrigger() external {
        vm.expectRevert(CannotSetNullAddress.selector);
        epochManager.setEpochEndTrigger(address(0), true);
    }

    function test_CannotDeleteTriggerThatDoesNotExist(address epochTrigger) external {
        vm.expectRevert('Trigger not found');
        epochManager.setEpochEndTrigger(epochTrigger, false);
    }

    function test_CannotSetExistingEpochEndTrigger(address epochTrigger) external {
        // Ensure we don't try to set a zero-address
        vm.assume(epochTrigger != address(0));

        epochManager.setEpochEndTrigger(epochTrigger, true);

        vm.expectRevert('Trigger already exists');
        epochManager.setEpochEndTrigger(epochTrigger, true);

        // Confirm that we can still re-apply it after it has been unset
        epochManager.setEpochEndTrigger(epochTrigger, false);
        epochManager.setEpochEndTrigger(epochTrigger, true);
    }

    function test_CannotReenterEndEpoch() external {
        // Set up a malicious contract that allows for reentry
        MaliciousEpochEndTrigger epochTrigger = new MaliciousEpochEndTrigger();

        // Assign it as an epoch end trigger
        epochManager.setEpochEndTrigger(address(epochTrigger), true);

        // Try and run epoch end, confirming that it would prevent reentry. This would
        // also be blocked by the timelock timestamp now being updated before the call,
        // but this just gives it an extra layer of security and peace of mind.
        vm.expectRevert('ReentrancyGuard: reentrant call');
        epochManager.endEpoch();
    }

}


contract MaliciousEpochEndTrigger is IEpochEndTriggered {

    function endEpoch(uint /* epoch */) external {
        EpochManager(msg.sender).endEpoch();
    }

}
