// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import {ERC721Mock} from './mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from './mocks/erc/ERC1155Mock.sol';
import {PricingExecutorMock} from './mocks/PricingExecutor.sol';

import {AccountDoesNotHaveRole} from '@floor/authorities/AuthorityControl.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {Vault} from '@floor/vaults/Vault.sol';
import {VaultFactory} from '@floor/vaults/VaultFactory.sol';
import {GaugeWeightVote} from '@floor/voting/GaugeWeightVote.sol';
import {EpochManager, EpochTimelocked, NoPricingExecutorSet} from '@floor/EpochManager.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, Treasury} from '@floor/Treasury.sol';

import {IVault} from '@floor-interfaces/vaults/Vault.sol';
import {IGaugeWeightVote} from '@floor-interfaces/voting/GaugeWeightVote.sol';

import {FloorTest} from './utilities/Environments.sol';

contract TreasuryTest is FloorTest {
    // We want to store a small number of specific users for testing
    address alice;
    address bob;
    address carol;

    address approvedCollection;

    // Track our internal contract addresses
    FLOOR floor;
    VeFloorStaking veFloor;
    ERC20Mock erc20;
    ERC721Mock erc721;
    ERC1155Mock erc1155;
    CollectionRegistry collectionRegistry;
    EpochManager epochManager;
    Treasury treasury;
    PricingExecutorMock pricingExecutorMock;
    GaugeWeightVote gaugeWeightVote;
    VaultFactory vaultFactory;

    constructor() {
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

        // Create our {VaultFactory}
        vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry)
        );

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(floor)
        );

        // Create our Gauge Weight Vote contract
        gaugeWeightVote = new GaugeWeightVote(
            address(collectionRegistry),
            address(vaultFactory),
            address(veFloor),
            address(authorityRegistry),
            address(treasury)
        );

        // Set up our {EpochManager}
        epochManager = new EpochManager();
        epochManager.setContracts(
            address(collectionRegistry),
            address(0),  // Floor Wars not needed for these tests
            address(pricingExecutorMock),
            address(treasury),
            address(vaultFactory),
            address(gaugeWeightVote),
            address(0)  // Vote Market not needed for these tests
        );

        // Set our epoch manager
        gaugeWeightVote.setEpochManager(address(epochManager));

        // Update our veFloor staking receiver to be the {Treasury}
        veFloor.setFeeReceiver(address(treasury));

        // Approve a collection
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        collectionRegistry.approveCollection(approvedCollection, SUFFICIENT_LIQUIDITY_COLLECTION);

        // Create our test users
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.REWARDS_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.VAULT_MANAGER(), address(treasury));

        // Give Bob the `TREASURY_MANAGER` role so that he can withdraw if needed
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), bob);

        // Wipe first token set up gas munch
        floor.mint(address(this), 1 ether);
        floor.transfer(address(1), 1 ether);
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
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
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

}
