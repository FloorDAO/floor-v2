// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {ERC20Mock} from './mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from './mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from './mocks/erc/ERC1155Mock.sol';
import {PricingExecutorMock} from './mocks/PricingExecutor.sol';
import {SweeperMock} from './mocks/Sweeper.sol';
import {MercenarySweeperMock} from './mocks/MercenarySweeper.sol';

import {WrapEth} from '@floor/actions/utils/WrapEth.sol';
import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {EpochManager, EpochTimelocked, NoPricingExecutorSet} from '@floor/EpochManager.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, Treasury} from '@floor/Treasury.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {FloorTest} from './utilities/Environments.sol';

contract TreasuryTest is FloorTest {
    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_641_210;

    // Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev Emitted when a sweep is registered
    event SweepRegistered(uint sweepEpoch, TreasuryEnums.SweepType sweepType, address[] collections, uint[] amounts);

    // We want to store a small number of specific users for testing
    address alice;
    address bob;
    address carol;

    address approvedCollection;

    /// Track our internal contract addresses
    FLOOR floor;
    VeFloorStaking veFloor;
    ERC20Mock erc20;
    ERC721Mock erc721;
    ERC1155Mock erc1155;
    CollectionRegistry collectionRegistry;
    EpochManager epochManager;
    Treasury treasury;
    PricingExecutorMock pricingExecutorMock;
    SweepWars sweepWars;
    StrategyFactory strategyFactory;
    SweeperMock sweeperMock;
    MercenarySweeperMock mercenarySweeperMock;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new VeFloorStaking(floor, address(this));

        // Set up a fake ERC20 token that we can test with. We use the {Floor} token
        // contract as a base as this already implements IERC20. We have no initial
        // balance.
        erc20 = new ERC20Mock();
        erc721 = new ERC721Mock();
        erc1155 = new ERC1155Mock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

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

        // Set our {VeFloorStaking} reference in the {Treasury} for sweeps
        treasury.setVeFloorStaking(address(veFloor));

        // Move some WETH to the Treasury to fund sweep tests
        deal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, address(treasury), 1000 ether);

        // Create our Gauge Weight Vote contract
        sweepWars = new SweepWars(
            address(collectionRegistry),
            address(strategyFactory),
            address(veFloor),
            address(authorityRegistry),
            address(treasury)
        );

        // Set up our {EpochManager}
        epochManager = new EpochManager();

        // Set our epoch manager
        veFloor.setEpochManager(address(epochManager));
        treasury.setEpochManager(address(epochManager));

        // Supply our {Treasury} with sufficient WETH for sweep tests
        deal(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, address(treasury), 1000 ether);

        // Update our veFloor staking receiver to be the {Treasury}
        veFloor.setFeeReceiver(address(treasury));

        // Approve a collection
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        collectionRegistry.approveCollection(approvedCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Create our test users
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), address(treasury));

        // Give Bob the `TREASURY_MANAGER` role so that he can withdraw if needed
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), bob);

        // Wipe first token set up gas munch
        floor.mint(address(this), 1 ether);
        floor.transfer(address(1), 1 ether);

        // Deploy and approve our sweeper mock
        sweeperMock = new SweeperMock(address(treasury));
        treasury.approveSweeper(address(sweeperMock), true);

        // Deploy a mercenary sweeper (this is currently just a mock)
        mercenarySweeperMock = new MercenarySweeperMock(address(treasury), address(erc721));
    }

    /**
     * Checks that an authorised user can an arbritrary amount of floor.
     *
     * This should emit {FloorMinted}.
     */
    function test_CanMintFloor(uint amount) public {
        amount = bound(amount, 1, 10000 ether);

        treasury.mint(amount);
        assertEq(floor.balanceOf(address(treasury)), amount);
    }

    /**
     * Ensure that only the {TreasuryManager} can action the minting of floor.
     *
     * This should not emit {FloorMinted}.
     */
    function test_CannotMintFloorWithoutPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.TREASURY_MANAGER()));
        vm.prank(alice);
        treasury.mint(100 ether);

        assertEq(floor.balanceOf(address(treasury)), 0);
    }

    /**
     * We should validate the amount passed into the floor minting to ensure that
     * a zero value cannot be requested.
     *
     * This should not emit {FloorMinted}.
     */
    function test_CannotMintZeroFloor() public {
        vm.expectRevert(InsufficientAmount.selector);
        treasury.mint(0);

        assertEq(floor.balanceOf(address(treasury)), 0);
    }

    /**
     * Our contract should be able to receive the native token of the chain.
     *
     * This should emit {Deposit}.
     */
    function test_CanDepositNativeToken(uint amount) public {
        vm.assume(amount <= address(alice).balance);

        // Confirm that the {Treasury} starts with 0ETH
        assertEq(address(treasury).balance, 0);

        // Send the {Treasury} 10ETH from Alice
        vm.prank(alice);
        (bool sent,) = address(treasury).call{value: amount}('');

        // Confirm that the ETH was sent successfully
        assertTrue(sent);

        // Confirm that the {Treasury} has received the expected 10ETH
        assertEq(address(treasury).balance, amount);
    }

    /**
     * We should be able to deposit any ERC20 token with varied amounts into
     * the {Treasury}.
     *
     * This should emit {DepositERC20}.
     */
    function test_CanDepositERC20(uint mintAmount, uint depositAmount) public {
        // The deposit amount must be <= the mint amount
        vm.assume(depositAmount <= mintAmount);

        // Give Alice tokens to facilitate the test
        erc20.mint(alice, mintAmount);

        // Confirm our starting balances
        assertEq(erc20.balanceOf(alice), mintAmount);
        assertEq(erc20.balanceOf(address(treasury)), 0);

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc20.approve(address(treasury), depositAmount);
        treasury.depositERC20(address(erc20), depositAmount);
        vm.stopPrank();

        // Confirm our closing balances
        assertEq(erc20.balanceOf(alice), mintAmount - depositAmount);
        assertEq(erc20.balanceOf(address(treasury)), depositAmount);
    }

    /**
     * We should be able to deposit any ERC721 token with varied amounts into
     * the {Treasury}.
     *
     * This should emit {DepositERC721}.
     */
    function test_CanDepositERC721(uint tokenId) public {
        // Give Alice an ERC721 to facilitate the test
        erc721.mint(alice, tokenId);

        // Confirm our starting owner of the ERC721
        assertEq(erc721.ownerOf(tokenId), alice);

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc721.approve(address(treasury), tokenId);
        treasury.depositERC721(address(erc721), tokenId);
        vm.stopPrank();

        // Confirm our closing owner
        assertEq(erc721.ownerOf(tokenId), address(treasury));
    }

    /**
     * We should be able to deposit any ERC1155 token with varied amounts into
     * the {Treasury}.
     *
     * This should emit {DepositERC1155}.
     */
    function test_CanDepositERC1155(uint tokenId, uint mintAmount, uint depositAmount) public {
        // The deposit amount must be <= the mint amount
        vm.assume(depositAmount <= mintAmount);

        // Give Alice an ERC1155 to facilitate the test
        erc1155.mint(alice, tokenId, mintAmount, '');

        // Confirm our starting owner of the ERC1155
        assertEq(erc1155.balanceOf(alice, tokenId), mintAmount);
        assertEq(erc1155.balanceOf(address(treasury), tokenId), 0);

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc1155.setApprovalForAll(address(treasury), true);
        treasury.depositERC1155(address(erc1155), tokenId, depositAmount);
        vm.stopPrank();

        // Confirm our closing owner
        assertEq(erc1155.balanceOf(alice, tokenId), mintAmount - depositAmount);
        assertEq(erc1155.balanceOf(address(treasury), tokenId), depositAmount);
    }

    /**
     * Our contract should be able to withdraw the native token of the chain.
     *
     * This should emit {Withdraw}.
     */
    function test_CanWithdrawNativeToken(uint depositAmount, uint withdrawAmount) public {
        // The deposit amount must be >= the withdraw amount, but less than Alice's ETH balance
        vm.assume(depositAmount >= withdrawAmount);
        vm.assume(depositAmount <= address(alice).balance);

        // Capture Alice's starting ETH balance
        uint aliceStartAmount = address(alice).balance;
        uint bobStartAmount = address(bob).balance;

        // Send the {Treasury} 10ETH from Alice
        vm.prank(alice);
        (bool sent,) = address(treasury).call{value: depositAmount}('');
        assertTrue(sent);

        // Confirm that the {Treasury} has received the expected 10ETH
        assertEq(address(treasury).balance, depositAmount);

        vm.prank(bob);
        treasury.withdraw(bob, withdrawAmount);

        assertEq(address(alice).balance, aliceStartAmount - depositAmount);
        assertEq(address(bob).balance, bobStartAmount + withdrawAmount);
        assertEq(address(treasury).balance, depositAmount - withdrawAmount);
    }

    /**
     * Our withdraw function only wants to be available to a specific user role
     * to ensure that not anyone can just rob us.
     *
     * This should not emit {Withdraw}.
     */
    function test_CannotWithdrawNativeTokenWithoutPermissions() public {
        // Send the {Treasury} 10ETH from Alice
        vm.prank(alice);
        (bool sent,) = address(treasury).call{value: 10 ether}('');
        assertTrue(sent);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(carol), authorityControl.TREASURY_MANAGER()));
        vm.prank(carol);
        treasury.withdraw(carol, 5 ether);
    }

    /**
     * We should be able to withdraw any ERC20 token with varied amounts from
     * the {Treasury}.
     *
     * This should emit {WithdrawERC20}.
     */
    function test_CanWithdrawERC20() public {
        // Give Alice tokens to facilitate the test
        erc20.mint(alice, 10 ether);

        // Confirm our starting balances
        assertEq(erc20.balanceOf(alice), 10 ether);
        assertEq(erc20.balanceOf(bob), 0);
        assertEq(erc20.balanceOf(address(treasury)), 0);

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc20.approve(address(treasury), 4 ether);
        treasury.depositERC20(address(erc20), 4 ether);
        vm.stopPrank();

        vm.prank(bob);
        treasury.withdrawERC20(bob, address(erc20), 3 ether);

        // Confirm our closing balances
        assertEq(erc20.balanceOf(alice), 6 ether);
        assertEq(erc20.balanceOf(bob), 3 ether);
        assertEq(erc20.balanceOf(address(treasury)), 1 ether);
    }

    /**
     * If we don't have the ERC20 token, or hold insufficient tokens, then we
     * expect a revert.
     *
     * This should not emit {WithdrawERC20}.
     */
    function test_CannotWithdrawInvalidERC20() public {
        vm.expectRevert('ERC20: transfer amount exceeds balance');
        vm.prank(bob);
        treasury.withdrawERC20(bob, address(erc20), 3 ether);
    }

    /**
     * If we don't have the right user role then we should not be able to transfer
     * the token and we expect a revert.
     *
     * This should not emit {WithdrawERC20}.
     */
    function test_CannotWithdrawERC20WithoutPermissions() public {
        // Give Alice tokens to facilitate the test
        erc20.mint(alice, 10 ether);

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc20.approve(address(treasury), 4 ether);
        treasury.depositERC20(address(erc20), 4 ether);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(carol), authorityControl.TREASURY_MANAGER()));
        vm.prank(carol);
        treasury.withdrawERC20(bob, address(erc20), 3 ether);
    }

    /**
     * We should be able to withdraw any ERC721 token with varied amounts from
     * the {Treasury}.
     *
     * This should emit {WithdrawERC721}.
     */
    function test_CanWithdrawERC721(uint tokenId) public {
        // Give Alice an ERC721 to facilitate the test
        erc721.mint(alice, tokenId);

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc721.approve(address(treasury), tokenId);
        treasury.depositERC721(address(erc721), tokenId);
        vm.stopPrank();

        // Withdraw the ERC721 to Bob's wallet
        vm.prank(bob);
        treasury.withdrawERC721(bob, address(erc721), tokenId);

        // Confirm our closing owner
        assertEq(erc721.ownerOf(tokenId), bob);
    }

    /**
     * If we don't have the ERC721 token, or hold insufficient tokens, then we
     * expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function test_CannotWithdrawInvalidERC721() public {
        // Withdraw the ERC721 to Bob's wallet
        vm.expectRevert('ERC721: invalid token ID');
        vm.prank(bob);
        treasury.withdrawERC721(bob, address(erc721), 123);
    }

    /**
     * If we don't have the right user role then we should not be able to transfer
     * the token and we expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function test_CannotWithdrawERC721WithoutPermissions() public {
        // Withdraw the ERC721 to Carol's wallet
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(carol), authorityControl.TREASURY_MANAGER()));
        vm.prank(carol);
        treasury.withdrawERC721(bob, address(erc721), 123);
    }

    /**
     * We should be able to withdraw any ERC1155 token with varied amounts from
     * the {Treasury}.
     *
     * This should emit {WithdrawERC721}.
     */
    function test_CanWithdrawERC1155(uint tokenId, uint depositAmount, uint withdrawAmount) public {
        // The deposit amount must be >= the withdraw amount
        vm.assume(depositAmount >= withdrawAmount);

        // Give Alice an ERC1155 to facilitate the test
        erc1155.mint(alice, tokenId, depositAmount, '');

        // Send the {Treasury} tokens from Alice
        vm.startPrank(alice);
        erc1155.setApprovalForAll(address(treasury), true);
        treasury.depositERC1155(address(erc1155), tokenId, depositAmount);
        vm.stopPrank();

        // Action a withdrawal to Bob's wallet
        vm.prank(bob);
        treasury.withdrawERC1155(bob, address(erc1155), tokenId, withdrawAmount);

        // Confirm owners of the ERC1155
        assertEq(erc1155.balanceOf(alice, tokenId), 0);
        assertEq(erc1155.balanceOf(bob, tokenId), withdrawAmount);
        assertEq(erc1155.balanceOf(address(treasury), tokenId), depositAmount - withdrawAmount);
    }

    /**
     * If we don't have the ERC1155 token, or hold insufficient tokens, then we
     * expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function test_CannotWithdrawInvalidERC1155() public {
        // Withdraw the ERC1155 to Bob's wallet
        vm.expectRevert('ERC1155: insufficient balance for transfer');
        vm.prank(bob);
        treasury.withdrawERC1155(bob, address(erc1155), 1, 1);
    }

    /**
     * If we don't have sufficient ERC1155 token amount, or hold insufficient tokens,
     * then we expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function test_CannotWithdrawInvalidERC1155Amount() public {
        // Give Alice an ERC1155 to facilitate the test
        erc1155.mint(alice, 1, 3, '');

        // Send the {Treasury} 2 tokens from Alice
        vm.startPrank(alice);
        erc1155.setApprovalForAll(address(treasury), true);
        treasury.depositERC1155(address(erc1155), 1, 2);
        vm.stopPrank();

        // Withdraw the ERC1155 to Bob's wallet
        vm.expectRevert('ERC1155: insufficient balance for transfer');
        vm.prank(bob);
        treasury.withdrawERC1155(bob, address(erc1155), 1, 3);
    }

    /**
     * If we don't have the right user role then we should not be able to transfer
     * the token and we expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function test_CannotWithdrawERC1155WithoutPermissions() public {
        // Give Alice an ERC1155 to facilitate the test
        erc1155.mint(alice, 1, 3, '');

        // Send the {Treasury} 2 tokens from Alice
        vm.startPrank(alice);
        erc1155.setApprovalForAll(address(treasury), true);
        treasury.depositERC1155(address(erc1155), 1, 3);
        vm.stopPrank();

        // Withdraw the ERC1155 to Bob's wallet
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(carol), authorityControl.TREASURY_MANAGER()));
        vm.prank(carol);
        treasury.withdrawERC1155(bob, address(erc1155), 1, 3);
    }

    function test_CanRegisterSweep(uint160 epoch) external {
        // We need to ensure there is a valid epoch after the fuzzy value
        vm.assume(epoch >= epochManager.currentEpoch());
        vm.assume(epoch < type(uint160).max);

        address[] memory collections = new address[](3);
        collections[0] = address(1);
        collections[1] = address(2);
        collections[2] = address(3);

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        // Confirm that we receive the expect event emit when the sweep is registered
        vm.expectEmit(true, true, false, true, address(treasury));
        emit SweepRegistered({
            sweepEpoch: epoch,
            sweepType: TreasuryEnums.SweepType.COLLECTION_ADDITION,
            collections: collections,
            amounts: amounts
        });

        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);        // Confirm that we receive the expect event emit when the sweep is registered

        // Pull the non-array data from the epochSweep object
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epoch);
        assertTrue(sweepType == TreasuryEnums.SweepType.COLLECTION_ADDITION);
        assertEq(completed, false);
        assertEq(message, '');

        vm.expectEmit(true, true, false, true, address(treasury));
        emit SweepRegistered({
            sweepEpoch: epoch + 1,
            sweepType: TreasuryEnums.SweepType.SWEEP,
            collections: collections,
            amounts: amounts
        });
        treasury.registerSweep(epoch + 1, collections, amounts, TreasuryEnums.SweepType.SWEEP);

        // Pull the non-array data from the epochSweep object
        (sweepType, completed, message) = treasury.epochSweeps(epoch + 1);
        assertTrue(sweepType == TreasuryEnums.SweepType.SWEEP);
        assertEq(completed, false);
        assertEq(message, '');
    }

    function test_CanOverwriteRegisteredSweep(uint epoch) external {
        address[] memory collections = new address[](3);
        collections[0] = address(1);
        collections[1] = address(2);
        collections[2] = address(3);

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        // Confirm that we receive the expect event emit when the sweep is registered
        vm.expectEmit(true, true, false, true, address(treasury));
        emit SweepRegistered({
            sweepEpoch: epoch,
            sweepType: TreasuryEnums.SweepType.SWEEP,
            collections: collections,
            amounts: amounts
        });

        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.SWEEP);

        amounts[2] = 4 ether;

        // Confirm that we receive the expect event emit when the sweep is registered
        vm.expectEmit(true, true, false, true, address(treasury));
        emit SweepRegistered({
            sweepEpoch: epoch,
            sweepType: TreasuryEnums.SweepType.SWEEP,
            collections: collections,
            amounts: amounts
        });

        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.SWEEP);
    }

    function test_CannotRegisterSweepWithoutPermissions(uint160 epoch) external {
        address[] memory collections = new address[](3);
        collections[0] = address(1);
        collections[1] = address(2);
        collections[2] = address(3);

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.SWEEP);
        vm.stopPrank();
    }

    function test_CannotRegisterSweepWithMismatchedCollectionsAndAmounts(uint160 epoch, uint8 _collections, uint8 _amounts) external {
        // Ensure that we have at least 1 collection
        vm.assume(_collections >= 1);

        // Ensure that our two array lengths are different
        vm.assume(_collections != _amounts);

        // We iterate over a uint160 loop so that it can be cast directly onto an address. We
        // increment our index by 1 for the address to avoid null address.
        address[] memory collections = new address[](_collections);
        for (uint160 i; i < _collections; ++i) {
            collections[i] = address(i + 1);
        }

        // Iterate over our amounts and give them slightly different values
        uint[] memory amounts = new uint[](_amounts);
        for (uint i; i < _amounts; ++i) {
            amounts[i] = i * 1 ether;
        }

        vm.expectRevert('Collections =/= amounts');
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.SWEEP);
    }

    function test_CanExecuteSweep(uint160 epoch) external {
        // We can't have a max value, as we need to increase it by 1
        vm.assume(epoch < type(uint160).max);

        // Register a sweep at the zero epoch
        _registerSweep(epoch);

        // Move to the next epoch to unlock
        setCurrentEpoch(address(epochManager), epoch + 1);

        // Sweep our epoch
        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);
    }

    function test_CannotExecuteSweepBeforeEpochHasPassed(uint160 epoch, uint160 sweepEpoch) external {
        // Ensure that the sweep is registered before we try and sweep
        vm.assume(sweepEpoch < epoch);

        // Register a sweep at the zero epoch
        _registerSweep(epoch);

        // Set our current epoch to one before the sweep is registered
        setCurrentEpoch(address(epochManager), sweepEpoch);

        // Confirm that we cannot sweep as the epoch has not yet passed
        vm.expectRevert('Epoch has not finished');
        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);
    }

    function test_CanExecuteSweepAsFloorHolder(uint160 epoch, uint160 sweepEpoch, uint floorBalance) external {
        vm.assume(epoch <= type(uint160).max - 2);
        vm.assume(sweepEpoch > epoch + 2);

        // Set our minimum floor balance requirement
        emit log_uint(floorBalance);
        vm.assume(floorBalance >= treasury.SWEEP_EXECUTE_TOKENS());

        // At the start of our test, we already mint 1 FLOOR token to power tests and we
        // may need to mint additional FLOOR tokens throughout. To avoid getting arithmatic
        // overflow, we limit the amount that is generated in the initial instance.
        floorBalance = bound(floorBalance, treasury.SWEEP_EXECUTE_TOKENS(), 10000 ether);
        _dealFloor(alice, floorBalance);

        _registerSweep(epoch);
        setCurrentEpoch(address(epochManager), sweepEpoch);

        vm.startPrank(alice);

        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);

        // Confirm we cannot sweep again
        vm.expectRevert('Epoch sweep already completed');
        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);

        vm.stopPrank();
    }

    function test_CannotExecuteSweepAsFloorHolderWithoutSufficientFloor(uint160 epoch, uint floorBalance) external {
        vm.assume(epoch <= type(uint160).max - 2);
        vm.assume(floorBalance < treasury.SWEEP_EXECUTE_TOKENS());

        _dealFloor(alice, floorBalance);

        _registerSweep(epoch);
        setCurrentEpoch(address(epochManager), epoch + 2);

        vm.expectRevert('Insufficient FLOOR holding');
        vm.prank(alice);
        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);
    }

    function test_CannotExecuteResweepAsFloorHolderRegardlessOfHolding(uint160 epoch, uint floorBalance) external {
        vm.assume(epoch <= type(uint160).max - 2);
        floorBalance = bound(floorBalance, treasury.SWEEP_EXECUTE_TOKENS(), 10000 ether);

        _dealFloor(alice, floorBalance);

        _registerSweep(epoch);
        setCurrentEpoch(address(epochManager), epoch + 2);

        vm.startPrank(alice);

        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);

        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, alice, authorityControl.TREASURY_MANAGER()));
        treasury.resweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);

        vm.stopPrank();
    }

    function test_CannotExecuteSweepAsFloorHolderBeforeExpectedEpoch(uint160 epoch) external {
        vm.assume(epoch < type(uint160).max - 1);

        _dealFloor(alice, treasury.SWEEP_EXECUTE_TOKENS());

        _registerSweep(epoch);
        setCurrentEpoch(address(epochManager), epoch + 1);

        vm.expectRevert('Only DAO may currently execute');
        vm.prank(alice);
        treasury.sweepEpoch(epoch, address(sweeperMock), 'Test Sweep', 0);
    }

    /**
     * Test actions can be triggered via the {Treasury}. Although this test will just
     * use a simple action that wraps WETH, we will additionally send multiple ERC
     * standards to be approved to test that logic also.
     */
    function test_CanCallAction() public {
        // Send some native token to the Treasury contract
        vm.prank(alice);
        (bool sent,) = address(treasury).call{value: 50 ether}('');
        assertEq(sent, true);

        // Give the {Treasury} some tokens to facilitate the test
        erc20.mint(address(treasury), 100 ether);
        erc721.mint(address(treasury), 1);
        erc721.mint(address(treasury), 2);
        erc1155.mint(address(treasury), 1, 3, '');
        erc1155.mint(address(treasury), 2, 2, '');

        WrapEth action = new WrapEth(WETH);

        ITreasury.ActionApproval[] memory approvals = new ITreasury.ActionApproval[](5);

        approvals[0] = ITreasury.ActionApproval(
            TreasuryEnums.ApprovalType.NATIVE, // Token type
            address(0), // address assetContract
            0, // uint tokenId
            30 ether // uint amount
        );

        approvals[1] = ITreasury.ActionApproval(
            TreasuryEnums.ApprovalType.ERC20, // Token type
            address(erc20), // address assetContract
            0, // uint tokenId
            50 ether // uint amount
        );

        approvals[2] = ITreasury.ActionApproval(
            TreasuryEnums.ApprovalType.ERC721, // Token type
            address(erc721), // address assetContract
            1, // uint tokenId
            0 // uint amount
        );

        approvals[3] = ITreasury.ActionApproval(
            TreasuryEnums.ApprovalType.ERC1155, // Token type
            address(erc1155), // address assetContract
            1, // uint tokenId
            2 // uint amount
        );

        approvals[4] = ITreasury.ActionApproval(
            TreasuryEnums.ApprovalType.ERC1155, // Token type
            address(erc1155), // address assetContract
            2, // uint tokenId
            2 // uint amount
        );

        treasury.processAction(
            payable(action), // address payable action
            approvals, // ActionApproval[] calldata approvals
            abi.encodePacked(uint(20 ether)), // bytes calldata data
            0 // uint linkedSweepEpoch
        );

        // Confirm the amount of ETH remaining
        assertEq(address(treasury).balance, 30 ether);

        // Confirm the amount of WETH received. We transferred 1000 WETH in our `constructor`
        // so we additionally need to keep this factored in.
        assertEq(IWETH(action.WETH()).balanceOf(address(treasury)), 1020 ether);

        // Test that ERC20 allowance reduced by 20 ether to 10 ether remaining
        assertEq(erc20.allowance(address(treasury), address(action)), 0);

        // ERC721 tokens should have no approvals as they will have been revoked if they
        // remained in the {Treasury}.
        assertEq(erc721.getApproved(1), address(0));
        assertEq(erc721.getApproved(2), address(0));

        // ERC1155 gets unapproved after
        assertEq(erc1155.isApprovedForAll(address(treasury), address(action)), false);
    }

    /**
     * Confirm that we can register a sweep against any epoch, present
     * or future. We should expect a revert if it is set in the past
     */
    function test_CanRegisterSweep(uint8 _sweepType, uint currentEpoch, uint epoch) external variesSweepType(_sweepType) {
        // Generate a test set of collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Ensure our sweep epoch is present, or in the future
        vm.assume(currentEpoch <= epoch);

        // Set our current epoch
        setCurrentEpoch(address(epochManager), currentEpoch);

        // Register a sweep. This epoch can be before, the same as, or after the `currentEpoch`
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Pull the non-array data from the epochSweep object
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epoch);

        // Confirm our data is as expected
        assertTrue(sweepType == TreasuryEnums.SweepType(_sweepType));
        assertEq(completed, false);
        assertEq(message, '');
    }

    /**
     * Confirm that we cannot register a sweep in a past epoch
     */
    function test_CannotRegisterSweepInPast(uint currentEpoch, uint epoch) external {
        // Generate a test set of collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Ensure our sweep epoch is before the current epoch
        vm.assume(currentEpoch > epoch);

        // Set our current epoch
        setCurrentEpoch(address(epochManager), currentEpoch);

        // Register a sweep. This epoch can be before, the same as, or after the `currentEpoch`
        vm.expectRevert('Invalid sweep epoch');
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.SWEEP);
    }

    /**
     * Confirm that a sweep can be overwritten.
     */
    function test_CanOverwriteTheRegisteredSweep(uint epoch) external {
        // Write our initial sweep
        (address[] memory collectionsA, uint[] memory amountsA) = _collectionsAndAmounts(3);
        treasury.registerSweep(epoch, collectionsA, amountsA, TreasuryEnums.SweepType.SWEEP);

        // Overwrite the sweep by registering the same epoch
        (address[] memory collectionsB, uint[] memory amountsB) = _collectionsAndAmounts(4);
        treasury.registerSweep(epoch, collectionsB, amountsB, TreasuryEnums.SweepType.COLLECTION_ADDITION);

        // Confirm that the information has updated
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epoch);
        assertTrue(sweepType == TreasuryEnums.SweepType.COLLECTION_ADDITION);
        assertEq(completed, false);
        assertEq(message, '');
    }

    /**
     * Confirm that a sweep cannot be registered without permissions.
     */
    function test_CannotRegisterSweepWithoutPermissions(uint8 _sweepType, address sender, uint epoch) external variesSweepType(_sweepType) {
        // Don't let the sender have permissions
        vm.assume(sender != address(this) && sender != bob);

        // Generate some test collection and amount data
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Try and register the collection as a user that does not have permissions
        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, sender, authorityControl.TREASURY_MANAGER()));
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));
        vm.stopPrank();
    }

    function test_CanSweepEpochAsDao(uint8 _sweepType, uint128 epoch, uint sweepEpoch) public variesSweepType(_sweepType) {
        // Set our sweep epoch to be `>= epoch + 1` as this is the expected executable range
        vm.assume(sweepEpoch > epoch);

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), epoch);

        // When we try and sweep it as the DAO owned address, we will receive a revert
        vm.expectRevert('Epoch has not finished');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Now we can set it to a subsequent epoch
        setCurrentEpoch(address(epochManager), sweepEpoch);
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Confirm that our epoch has been marked as completed
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epoch);
        assertTrue(sweepType == TreasuryEnums.SweepType(_sweepType));
        assertEq(completed, true);
        assertEq(message, '');
    }

    function test_CanSweepEpochAsTokenHolder(uint8 _sweepType, uint epoch, uint sweepEpoch) public variesSweepType(_sweepType) {
        // Set our sweep epoch to be `>= epoch + 2` as this is the expected executable range
        vm.assume(epoch < type(uint128).max);
        vm.assume(sweepEpoch >= epoch + 2);

        // Provide our test user with enough tokens to successfully sweep
        _dealFloor(alice, treasury.SWEEP_EXECUTE_TOKENS());

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Set the epoch to the same as the sweep. This should not be sweepable by a token
        // holder. When we try and sweep it as a token holder address, we will receive a revert.
        setCurrentEpoch(address(epochManager), epoch);
        vm.prank(alice);
        vm.expectRevert('Epoch has not finished');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Set the epoch to the subsequent of the sweep. This should not be sweepable by a token
        // holder. When we try and sweep it as a token holder address, we will receive a revert.
        setCurrentEpoch(address(epochManager), epoch + 1);
        vm.prank(alice);
        vm.expectRevert('Only DAO may currently execute');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Now we can set it to a subsequent epoch
        setCurrentEpoch(address(epochManager), sweepEpoch);
        vm.prank(alice);
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Confirm that our epoch has been marked as completed
        (TreasuryEnums.SweepType sweepType, bool completed, string memory message) = treasury.epochSweeps(epoch);
        assertTrue(sweepType == TreasuryEnums.SweepType(_sweepType));
        assertEq(completed, true);
        assertEq(message, '');
    }

    /**
     *
     */
    function test_CannotSweepNonTokenHolderEpochAsTokenHolder(uint8 _sweepType, uint128 epoch, uint sweepEpoch) public variesSweepType(_sweepType) {
        // We want to be able to test a sweep in any epoch that is < epoch +
        vm.assume(sweepEpoch < uint(epoch) + 2);

        // Provide our test user with enough tokens to successfully sweep
        deal(address(floor), alice, treasury.SWEEP_EXECUTE_TOKENS());

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Set the epoch to the same as the sweep. This should not be sweepable by a token
        // holder. When we try and sweep it as a token holder address, we will receive a revert.
        setCurrentEpoch(address(epochManager), sweepEpoch);

        vm.startPrank(alice);

        // Our error code may change, depending on the epoch at which the sweep occurs
        if (sweepEpoch <= epoch) {
            vm.expectRevert('Epoch has not finished');
        }
        else if (sweepEpoch == uint(epoch) + 1) {
            vm.expectRevert('Only DAO may currently execute');
        }

        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);
    }

    function test_CannotSweepEpochWithInsufficientTokenHoldings(uint8 _sweepType, uint epoch, uint sweepEpoch, uint tokenHolding) public variesSweepType(_sweepType) {
        // Set our sweep epoch to be `>= epoch + 2` as this is the expected executable range
        vm.assume(epoch < type(uint128).max);
        vm.assume(sweepEpoch >= epoch + 2);

        // Provide our test user with insufficient tokens to sweep
        vm.assume(tokenHolding < treasury.SWEEP_EXECUTE_TOKENS());
        deal(address(floor), alice, tokenHolding);

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Set the epoch to the same as the sweep. This should not be sweepable by a token
        // holder. When we try and sweep it as a token holder address, we will receive a revert.
        setCurrentEpoch(address(epochManager), epoch);
        vm.prank(alice);
        vm.expectRevert('Epoch has not finished');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Set the epoch to the subsequent of the sweep. This should not be sweepable by a token
        // holder. When we try and sweep it as a token holder address, we will receive a revert.
        setCurrentEpoch(address(epochManager), epoch + 1);
        vm.prank(alice);
        vm.expectRevert('Only DAO may currently execute');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Now we can set it to a subsequent epoch, but we still won't be able to sweep it as we
        // have insufficient token holdings
        setCurrentEpoch(address(epochManager), sweepEpoch);
        vm.prank(alice);
        vm.expectRevert('Insufficient FLOOR holding');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);
    }

    function test_CannotSweepCompletedEpoch(uint8 _sweepType, uint epoch) external variesSweepType(_sweepType) {
        // Prevent epoch value overflow when we add 2 later in the test
        vm.assume(epoch <= type(uint128).max);

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Provide our test user with sufficient tokens to sweep
        deal(address(floor), alice, treasury.SWEEP_EXECUTE_TOKENS());

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), epoch + 2);

        // Sweep successfully as the DAO initially
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Confirm that our epoch has been marked as completed
        (, bool completed,) = treasury.epochSweeps(epoch);
        assertEq(completed, true);

        // We now try to sweep again as the DAO, which should revert
        vm.expectRevert('Epoch sweep already completed');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // And we can also try to sweep as a token holder, which should also revert
        vm.prank(alice);
        vm.expectRevert('Epoch sweep already completed');
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);
    }

    function test_CanResweepEpochWithCorrectPermissions(uint8 _sweepType, uint128 epoch, uint sweepEpoch) external variesSweepType(_sweepType) {
        // Set our sweep epoch to be greater than the epoch as this is the expected
        // executable range.
        vm.assume(sweepEpoch > epoch);

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Shift our epoch, even though this won't have any effect
        setCurrentEpoch(address(epochManager), sweepEpoch);

        // Sweep our epoch
        treasury.sweepEpoch(epoch, address(sweeperMock), '', 0);

        // Confirm that our epoch has been marked as completed
        (, bool completed,) = treasury.epochSweeps(epoch);
        assertEq(completed, true);

        // Now we can resweep it any number of times as a permissioned account
        treasury.resweepEpoch(epoch, address(sweeperMock), '', 0);
        treasury.resweepEpoch(epoch, address(sweeperMock), '', 0);
        treasury.resweepEpoch(epoch, address(sweeperMock), '', 0);
    }

    function test_CannotResweepEpochWithoutCorrectPermissions(uint8 _sweepType, uint epoch, uint sweepEpoch) external variesSweepType(_sweepType) {
        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Provide our test user with sufficient tokens to sweep
        deal(address(floor), alice, treasury.SWEEP_EXECUTE_TOKENS());

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Shift our epoch, even though this won't have any effect
        setCurrentEpoch(address(epochManager), sweepEpoch);

        // Try and resweep without having swept the epoch first
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        treasury.resweepEpoch(epoch, address(sweeperMock), '', 0);
        vm.stopPrank();
    }

    function test_CannotResweepEpochWithoutItAlreadyHavingBeenSwept(uint8 _sweepType, uint epoch, uint sweepEpoch) external variesSweepType(_sweepType) {
        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Shift our epoch, even though this won't have any effect
        setCurrentEpoch(address(epochManager), sweepEpoch);

        // Try and resweep without having swept the epoch first
        vm.expectRevert('Epoch not swept');
        treasury.resweepEpoch(epoch, address(sweeperMock), '', 0);
    }

    /**
     * Ensure that the `mercenarySweeper` can be updated by someone with permissions to
     * any value.
     */
    function test_CanSetMercenarySweeper(address mercSweeper) external {
        treasury.setMercenarySweeper(mercSweeper);
        assertEq(address(treasury.mercSweeper()), mercSweeper);
    }

    /**
     * Ensure that the `mercenarySweeper` cannot be updated by someone without permissions.
     */
    function test_CannotSetMercenarySweeperWithoutPermissions(address mercSweeper) external {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        treasury.setMercenarySweeper(mercSweeper);
        vm.stopPrank();
    }

    /**
     * Ensure that we can approve a sweeper contract, unapprove it and then reapprove it
     * without causing any conflict. This test also checks that trying to update the state
     * of a sweeper to the state it is already assigned to will not break it.
     */
    function test_CanApproveSweeper(address sweeper) external {
        // Ensure we don't trip and the already deployed sweeper contract
        vm.assume(sweeper != address(sweeperMock));

        // Confirm that the sweeper starts unapproved
        assertFalse(treasury.approvedSweepers(sweeper));

        // Approve our sweeper and confirm that it has applied
        treasury.approveSweeper(sweeper, true);
        assertTrue(treasury.approvedSweepers(sweeper));

        // Confirm that we can approve and already approved sweeper
        treasury.approveSweeper(sweeper, true);
        assertTrue(treasury.approvedSweepers(sweeper));

        // Unapprove our sweeper and confirm it was applied
        treasury.approveSweeper(sweeper, false);
        assertFalse(treasury.approvedSweepers(sweeper));

        // Confirm that we can unapprove and already unapproved sweeper
        treasury.approveSweeper(sweeper, false);
        assertFalse(treasury.approvedSweepers(sweeper));

        // Finally, confirm that we can re-approve a sweeper
        treasury.approveSweeper(sweeper, true);
        assertTrue(treasury.approvedSweepers(sweeper));
    }

    /**
     * Ensure that the `minSweepAmount` can be updated by someone with permissions to
     * any value.
     */
    function test_CanSetMinSweepAmount(uint minAmount) external {
        treasury.setMinSweepAmount(minAmount);
        assertEq(treasury.minSweepAmount(), minAmount);
    }

    /**
     * Ensure that the `minSweepAmount` cannot be updated by someone without permissions.
     */
    function test_CannotSetMinSweepAmountWithoutPermissions(uint minAmount) external {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        treasury.setMinSweepAmount(minAmount);
        vm.stopPrank();
    }

    function test_CannotSweepWithUnapprovedSweeper(uint8 _sweepType, uint128 epoch, uint sweepEpoch) external variesSweepType(_sweepType) {
        // Set our sweep epoch to be `>= epoch + 1` as this is the expected executable range
        vm.assume(sweepEpoch > epoch);

        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(3);

        // Register a sweep to test against
        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType(_sweepType));

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), sweepEpoch);

        // When we try and sweep it as the DAO owned address, we will receive a revert
        vm.expectRevert('Sweeper contract not approved');
        treasury.sweepEpoch(epoch, address(1), '', 0);
    }

    function test_CanOnlyUseMercenarySweepingForNewCollections() external hasMercenarySweeper {
        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(1);

        // Register a sweep to test against
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.SWEEP);

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), 1);

        // When we try and sweep it as the DAO owned address, we will receive a revert
        vm.expectRevert('Merc Sweep only available for collection additions');
        treasury.sweepEpoch(0, address(sweeperMock), '', 1);
    }

    function test_CanOnlyUseMercenarySweepingUnderOrEqualToAmountValue(uint mercSweepAmount) external hasMercenarySweeper {
        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(1);

        // Ensure our sweep amount is below the amount
        vm.assume(mercSweepAmount > amounts[0]);

        // Register a sweep to test against
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), 1);

        // When we try and sweep it as the DAO owned address, we will receive a revert
        vm.expectRevert('Merc Sweep cannot be higher than msg.value');
        treasury.sweepEpoch(0, address(sweeperMock), '', mercSweepAmount);
    }

    function test_CanOnlyUseMercenarySweepingIfContractIsSet() external {
        // Get some test collections and amounts
        (address[] memory collections, uint[] memory amounts) = _collectionsAndAmounts(1);

        // Register a sweep to test against
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), 1);

        // When we try and sweep it as the DAO owned address, we will receive a revert
        vm.expectRevert('Merc Sweeper not set');
        treasury.sweepEpoch(0, address(sweeperMock), '', 1);
    }

    function test_CanUseMercenarySweeperWithAnotherSweeper(uint8 _mercSweepAmount, uint tokenAmount) external hasMercenarySweeper {
        // Ensure we don't surpass our {Treasury} WETH holdings
        uint mercSweepAmount = uint(_mercSweepAmount) * 1 ether;  // 0 - 255 ERC721 tokens
        vm.assume(tokenAmount <= 1000 ether - mercSweepAmount);

        // Set up a test collection and amount
        address[] memory collections = new address[](1);
        uint[] memory amounts = new uint[](1);
        collections[0] = address(new ERC20Mock());
        amounts[0] = mercSweepAmount + tokenAmount;

        // Register a sweep to test against
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), 1);

        // Confirm we can make the call against a sweeper mock and also against a merc
        // sweeper in the same call. The merc sweeper will return erc721 tokens, but the
        // normal sweeper will return erc20 tokens.
        treasury.sweepEpoch(0, address(sweeperMock), '', _mercSweepAmount);

        // Our {Treasury} should now own the expected tokens
        for (uint i = 1; i <= uint(_mercSweepAmount); i++) {
            assertEq(erc721.ownerOf(i), address(treasury));
        }

        // The sweep should have completed to return us an additional amount in ERC20 tokens
        assertEq(IERC20(collections[0]).balanceOf(address(treasury)), tokenAmount);
    }

    function test_CanUseMercenarySweeperAsOnlySweeper(uint8 mercSweepAmount) external hasMercenarySweeper {
        // Set up a test collection and amount
        address[] memory collections = new address[](1);
        uint[] memory amounts = new uint[](1);

        collections[0] = address(new ERC20Mock());
        amounts[0] = uint(mercSweepAmount) * 1 ether;

        // Register a sweep to test against
        treasury.registerSweep(0, collections, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);

        // Set the epoch to the same as the sweep. This should not be sweepable by the DAO
        setCurrentEpoch(address(epochManager), 1);

        // Confirm we can make the call against only a merc sweeper when the full value is
        // set. The merc sweeper will return erc721 tokens, and we should receive no erc20
        // tokens.
        treasury.sweepEpoch(0, address(sweeperMock), '', mercSweepAmount);

        // Our {Treasury} should now own the expected tokens
        for (uint8 i; i < mercSweepAmount; i++) {
            assertEq(erc721.ownerOf(uint(i) + 1), address(treasury));
        }

        // We should have received no ERC20 balance as the sweeper mock will not have been called
        assertEq(IERC20(collections[0]).balanceOf(address(treasury)), 0);
    }

    /**
     * Builds a mocked collection and amounts array. This is called internally to help create
     * quick arrays in which the internal data is not important. Values will be incremented from
     * 1 a zero amount value. Each collection will be a deployed ERC20 contract so that sweepers
     * can handle calls within them.
     *
     * @return collections Array of addresses
     * @return amounts Array of 18-decimal amounts
     */
    function _collectionsAndAmounts(uint count) internal returns (address[] memory collections, uint[] memory amounts) {
        collections = new address[](count);
        amounts = new uint[](count);

        for (uint160 i; i < count; ++i) {
            collections[i] = address(new ERC20Mock());
            amounts[i] = (i + 1) * 1 ether;
        }
    }

    function _registerSweep(uint epoch) internal {
        address[] memory collections = new address[](3);
        collections[0] = address(new ERC20Mock());
        collections[1] = address(new ERC20Mock());
        collections[2] = address(new ERC20Mock());

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        treasury.registerSweep(epoch, collections, amounts, TreasuryEnums.SweepType.COLLECTION_ADDITION);
    }

    function _dealFloor(address recipient, uint amount) internal {
        // Mint FLOOR tokens to the user we are testing with
        floor.mint(recipient, amount);

        // Stake the floor tokens into veFloor staking at the full duration
        vm.startPrank(recipient);
        floor.approve(address(veFloor), amount);
        veFloor.deposit(amount, 3);
        vm.stopPrank();
    }

    /**
     * ..
     */
    modifier variesSweepType(uint8 _sweepType) {
        // We only have 2 sweep types, so we want to toggle it between those indexes
        vm.assume(_sweepType <= 1);

        _;
    }

    /**
     * ..
     */
    modifier hasMercenarySweeper() {
        treasury.setMercenarySweeper(address(mercenarySweeperMock));
        _;
    }
}
