// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import './mocks/erc/ERC721Mock.sol';
import './mocks/erc/ERC1155Mock.sol';
import './mocks/PricingExecutor.sol';

import '../src/contracts/collections/CollectionRegistry.sol';
import '../src/contracts/tokens/Floor.sol';
import '../src/contracts/tokens/VaultXToken.sol';
import {VeFloorStaking} from '../src/contracts/staking/VeFloorStaking.sol';
import '../src/contracts/strategies/StrategyRegistry.sol';
import '../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import '../src/contracts/vaults/Vault.sol';
import {VaultFactory} from '../src/contracts/vaults/VaultFactory.sol';
import {GaugeWeightVote} from '../src/contracts/voting/GaugeWeightVote.sol';
import '../src/contracts/Treasury.sol';

import '../src/interfaces/vaults/Vault.sol';
import '../src/interfaces/voting/GaugeWeightVote.sol';

import './utilities/Environments.sol';

contract TreasuryTest is FloorTest {
    // We want to store a small number of specific users for testing
    address alice;
    address bob;
    address carol;

    address approvedStrategy;
    address approvedCollection;

    // Track our internal contract addresses
    FLOOR floor;
    VeFloorStaking veFloor;
    ERC20Mock erc20;
    ERC721Mock erc721;
    ERC1155Mock erc1155;
    CollectionRegistry collectionRegistry;
    StrategyRegistry strategyRegistry;
    Treasury treasury;
    PricingExecutorMock pricingExecutorMock;
    GaugeWeightVote gaugeWeightVote;
    VaultFactory vaultFactory;

    constructor() {
        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new VeFloorStaking(floor, STAKING_EXP_BASE, address(this));

        // Set up a fake ERC20 token that we can test with. We use the {Floor} token
        // contract as a base as this already implements IERC20. We have no initial
        // balance.
        erc20 = new ERC20Mock();
        erc721 = new ERC721Mock();
        erc1155 = new ERC1155Mock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Approve a strategy
        approvedStrategy = address(new NFTXInventoryStakingStrategy(bytes32('Approved Strategy')));
        strategyRegistry.approveStrategy(approvedStrategy);

        // Approve a collection
        approvedCollection = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        collectionRegistry.approveCollection(approvedCollection);

        // Deploy our vault implementations
        address vaultImplementation = address(new Vault());
        address vaultXTokenImplementation = address(new VaultXToken());

        // Create our {VaultFactory}
        vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            vaultImplementation,
            vaultXTokenImplementation,
            address(floor)
        );

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            address(vaultFactory),
            address(floor)
        );

        // Create our Gauge Weight Vote contract
        gaugeWeightVote = new GaugeWeightVote(
            address(collectionRegistry),
            address(vaultFactory),
            address(veFloor),
            address(authorityRegistry)
        );

        // Update our veFloor staking receiver to be the {Treasury}
        veFloor.setFeeReceiver(address(treasury));

        // Create our test users
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.REWARDS_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.VAULT_MANAGER(), address(treasury));

        // Give Bob the `TREASURY_MANAGER` role so that he can withdraw if needed
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), bob);

        authorityRegistry.grantRole(authorityControl.STAKING_MANAGER(), address(vaultXTokenImplementation));
    }

    /**
     * Checks that an authorised user can an arbritrary amount of floor.
     *
     * This should emit {FloorMinted}.
     */
    function test_CanMintFloor(uint amount) public {
        vm.assume(amount > 0);

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

    /**
     * Gauge Weight Vote get/set.
     */
    function test_CanSetGaugeWeightVoteContract() public {
        assertEq(address(treasury.voteContract()), address(0));

        treasury.setGaugeWeightVoteContract(address(1));
        assertEq(address(treasury.voteContract()), address(1));
    }

    function test_CannotSetGaugeWeightVoteContractNullValue() public {
        vm.expectRevert(CannotSetNullAddress.selector);
        treasury.setGaugeWeightVoteContract(address(0));
    }

    function test_CannotSetGaugeWeightVoteContractWithoutPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        vm.prank(alice);
        treasury.setGaugeWeightVoteContract(address(1));
    }

    /**
     * Retained Treasury Yield Percentage get/set.
     */
    function test_CanSetRetainedTreasuryYieldPercentage(uint percentage) public {
        vm.assume(percentage <= 10000);

        assertEq(treasury.retainedTreasuryYieldPercentage(), 0);

        treasury.setRetainedTreasuryYieldPercentage(percentage);
        assertEq(treasury.retainedTreasuryYieldPercentage(), percentage);
    }

    function test_CannotSetRetainedTreasuryYieldPercentageOverOneHundredPercent(uint percentage) public {
        // Ensure our test amount is over 100%
        vm.assume(percentage > 10000);

        vm.expectRevert(abi.encodeWithSelector(PercentageTooHigh.selector, 10000));
        treasury.setRetainedTreasuryYieldPercentage(percentage);
    }

    function test_CannotSetRetainedTreasuryYieldPercentageWithoutPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        vm.prank(alice);
        treasury.setRetainedTreasuryYieldPercentage(0);
    }

    /**
     * We need to be able to get the equivalent floor token price of another token
     * through using a known pricing executor. For the purposes of this test we can
     * use a Mock.
     */
    function test_CanGetTokenFloorPrice() public {
        // We first need to set our pricing executor to the Mock
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Set test addresses as approved collections
        collectionRegistry.approveCollection(address(1));
        collectionRegistry.approveCollection(address(2));
        collectionRegistry.approveCollection(address(3));
        collectionRegistry.approveCollection(address(4));

        // Our pricing executor Mock has preset address -> uint mapping for
        // the price. So we can at first expect 0 prices, but then after our
        // call we can expect specific prices.
        assertEq(treasury.tokenFloorPrice(address(1)), 0);
        assertEq(treasury.tokenFloorPrice(address(2)), 0);
        assertEq(treasury.tokenFloorPrice(address(3)), 0);
        assertEq(treasury.tokenFloorPrice(address(4)), 0);

        // Call our pricing executor, querying the prices and writing it to
        // to our {Treasury} pricing cache.
        treasury.getCollectionFloorPrices();

        assertEq(treasury.tokenFloorPrice(address(1)), 11);
        assertEq(treasury.tokenFloorPrice(address(2)), 22);
        assertEq(treasury.tokenFloorPrice(address(3)), 33);
        assertEq(treasury.tokenFloorPrice(address(4)), 44);
    }

    /**
     * If we don't have a pricing executor set, then we won't be able to query
     * anything and we should have our call reverted.
     */
    function test_CannotGetFloorPricesWithoutPricingExecutor() public {
        vm.expectRevert(NoPricingExecutorSet.selector);
        treasury.getCollectionFloorPrices();
    }

    /**
     * Pricing Executor get/set.
     */
    function test_CanSetPricingExecutor() public {
        assertEq(address(treasury.pricingExecutor()), address(0));

        treasury.setPricingExecutor(address(1));
        assertEq(address(treasury.pricingExecutor()), address(1));
    }

    function test_CannotSetPricingExecutorNullValue() public {
        vm.expectRevert(CannotSetNullAddress.selector);
        treasury.setPricingExecutor(address(0));
    }

    function test_CannotSetPricingExecutorWithoutPermissions() public {
        vm.expectRevert(abi.encodeWithSelector(AccountDoesNotHaveRole.selector, address(alice), authorityControl.TREASURY_MANAGER()));
        vm.prank(alice);
        treasury.setPricingExecutor(address(1));
    }

    /**
     * When the epoch ends, the {TreasuryManager} can call to end the epoch. This
     * will generate FLOOR against the token rewards, determine the yield of the
     * {Treasury} to generate additional FLOOR through `RetainedTreasuryYieldPercentage`.
     *
     * We will then need to reference this against the {RewardsLedger} and the
     * {GaugeWeightVote} to confirm that all test users are allocated their correct
     * share.
     *
     * This will be quite a large test. Brace yourselves!
     */
    function test_CanEndEpoch() public {
        // Set our required internal contracts
        treasury.setGaugeWeightVoteContract(address(gaugeWeightVote));
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Approve our vault collections
        collectionRegistry.approveCollection(address(1));
        collectionRegistry.approveCollection(address(2));
        collectionRegistry.approveCollection(address(3));
        collectionRegistry.approveCollection(address(4));

        // Prevent the {VaultFactory} from trying to transfer tokens when registering the mint
        vm.mockCall(address(vaultFactory), abi.encodeWithSelector(VaultFactory.registerMint.selector), abi.encode(''));

        // Mock our vaults response (our {VaultFactory} has a hardcoded address(8) when we
        // set up the {Treasury} contract).
        address[] memory vaults = new address[](5);
        (, vaults[0]) = vaultFactory.createVault('Test Vault 1', approvedStrategy, _strategyInitBytes(), address(1));
        (, vaults[1]) = vaultFactory.createVault('Test Vault 2', approvedStrategy, _strategyInitBytes(), address(2));
        (, vaults[2]) = vaultFactory.createVault('Test Vault 3', approvedStrategy, _strategyInitBytes(), address(2));
        (, vaults[3]) = vaultFactory.createVault('Test Vault 4', approvedStrategy, _strategyInitBytes(), address(3));
        (, vaults[4]) = vaultFactory.createVault('Test Vault 5', approvedStrategy, _strategyInitBytes(), address(4));

        // Create a unique set of test users
        users = utilities.createUsers(8, 0);

        // Mock our rewards yield claim amount. For simplicity of future calculations, I've made
        // these the same as the number of users that have (mock) staked against to it
        vm.mockCall(vaults[0], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(8 ether)));
        vm.mockCall(vaults[1], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(1 ether)));
        vm.mockCall(vaults[2], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(5 ether)));
        vm.mockCall(vaults[3], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(6 ether)));
        vm.mockCall(vaults[4], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(4 ether)));

        // Reference our vault xToken contracts
        VaultXToken[] memory vaultXTokens = new VaultXToken[](vaults.length);
        for (uint i; i < vaults.length; ++i) {
            vaultXTokens[i] = VaultXToken(Vault(vaults[i]).xToken());
        }

        // Set up our vault shares by assigning vault xTokens
        vm.startPrank(vaults[0]);
        vaultXTokens[0].mint(address(treasury), 300 ether);
        vaultXTokens[0].mint(address(users[0]), 100 ether);
        vaultXTokens[0].mint(address(users[1]), 150 ether);
        vaultXTokens[0].mint(address(users[2]), 150 ether);
        vaultXTokens[0].mint(address(users[3]), 200 ether);
        vaultXTokens[0].mint(address(users[4]), 50 ether);
        vaultXTokens[0].mint(address(users[5]), 30 ether);
        vm.stopPrank();

        vm.startPrank(vaults[1]);
        vaultXTokens[1].mint(address(treasury), 1000 ether);
        vm.stopPrank();

        vm.startPrank(vaults[2]);
        vaultXTokens[2].mint(address(treasury), 200 ether);
        vaultXTokens[2].mint(address(users[3]), 200 ether);
        vaultXTokens[2].mint(address(users[4]), 250 ether);
        vaultXTokens[2].mint(address(users[6]), 250 ether);
        vaultXTokens[2].mint(address(users[7]), 100 ether);
        vm.stopPrank();

        vm.startPrank(vaults[3]);
        vaultXTokens[3].mint(address(treasury), 200 ether);
        vaultXTokens[3].mint(address(users[0]), 250 ether);
        vaultXTokens[3].mint(address(users[2]), 250 ether);
        vaultXTokens[3].mint(address(users[4]), 100 ether);
        vaultXTokens[3].mint(address(users[6]), 100 ether);
        vaultXTokens[3].mint(address(users[7]), 100 ether);
        vm.stopPrank();

        vm.startPrank(vaults[4]);
        vaultXTokens[4].mint(address(treasury), 250 ether);
        vaultXTokens[4].mint(address(users[5]), 250 ether);
        vaultXTokens[4].mint(address(users[6]), 250 ether);
        vaultXTokens[4].mint(address(users[7]), 250 ether);
        vm.stopPrank();

        // Mock vault share recalculation (ignore)
        vm.mockCall(address(vaultFactory), abi.encodeWithSelector(Vault.migratePendingDeposits.selector), abi.encode(''));

        // Trigger our epoch end
        treasury.endEpoch();

        // Confirm the amount allocated to each user on each xToken. The {Treasury} will
        // not hold any tokens as they will have been burnt.
        assertEq(vaultXTokens[0].dividendOf(address(treasury)), 0);
        assertEq(vaultXTokens[1].dividendOf(address(treasury)), 0);
        assertEq(vaultXTokens[2].dividendOf(address(treasury)), 0);
        assertEq(vaultXTokens[3].dividendOf(address(treasury)), 0);
        assertEq(vaultXTokens[4].dividendOf(address(treasury)), 0);

        assertEq(vaultXTokens[0].dividendOf(users[0]), 8979591836734693877);
        assertEq(vaultXTokens[1].dividendOf(users[0]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[0]), 0);
        assertEq(vaultXTokens[3].dividendOf(users[0]), 49499999999999999999);
        assertEq(vaultXTokens[4].dividendOf(users[0]), 0);

        assertEq(vaultXTokens[0].dividendOf(users[1]), 13469387755102040816);
        assertEq(vaultXTokens[1].dividendOf(users[1]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[1]), 0);
        assertEq(vaultXTokens[3].dividendOf(users[1]), 0);
        assertEq(vaultXTokens[4].dividendOf(users[1]), 0);

        assertEq(vaultXTokens[0].dividendOf(users[2]), 13469387755102040816);
        assertEq(vaultXTokens[1].dividendOf(users[2]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[2]), 0);
        assertEq(vaultXTokens[3].dividendOf(users[2]), 49499999999999999999);
        assertEq(vaultXTokens[4].dividendOf(users[2]), 0);

        assertEq(vaultXTokens[0].dividendOf(users[3]), 17959183673469387755);
        assertEq(vaultXTokens[1].dividendOf(users[3]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[3]), 21999999999999999999);
        assertEq(vaultXTokens[3].dividendOf(users[3]), 0);
        assertEq(vaultXTokens[4].dividendOf(users[3]), 0);

        assertEq(vaultXTokens[0].dividendOf(users[4]), 4489795918367346938);
        assertEq(vaultXTokens[1].dividendOf(users[4]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[4]), 27499999999999999999);
        assertEq(vaultXTokens[3].dividendOf(users[4]), 19799999999999999999);
        assertEq(vaultXTokens[4].dividendOf(users[4]), 0);

        assertEq(vaultXTokens[0].dividendOf(users[5]), 2693877551020408163);
        assertEq(vaultXTokens[1].dividendOf(users[5]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[5]), 0);
        assertEq(vaultXTokens[3].dividendOf(users[5]), 0);
        assertEq(vaultXTokens[4].dividendOf(users[5]), 43999999999999999999);

        assertEq(vaultXTokens[0].dividendOf(users[6]), 0);
        assertEq(vaultXTokens[1].dividendOf(users[6]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[6]), 27499999999999999999);
        assertEq(vaultXTokens[3].dividendOf(users[6]), 19799999999999999999);
        assertEq(vaultXTokens[4].dividendOf(users[6]), 43999999999999999999);

        assertEq(vaultXTokens[0].dividendOf(users[7]), 0);
        assertEq(vaultXTokens[1].dividendOf(users[7]), 0);
        assertEq(vaultXTokens[2].dividendOf(users[7]), 10999999999999999999);
        assertEq(vaultXTokens[3].dividendOf(users[7]), 19799999999999999999);
        assertEq(vaultXTokens[4].dividendOf(users[7]), 43999999999999999999);

        // The {Treasury} will not hold the tokens, they will be in the individual
        // vaults. Tokens that would have been attributed to the {Treasury} will
        // have been burnt.

        // 154538775510204081628
        // 154538775510204081628

        assertEq(floor.balanceOf(address(treasury)), 0);
    }

    /**
     * After an epoch has run, there is a minimum wait that must be respected before
     * trying to run it again. If this is not catered for, then we expect a revert.
     */
    function test_CannotCallAnotherEpochWithoutRespectingTimeout() public {
        // Set our required internal contracts
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Mock our VaultFactory call to return no vaults
        vm.mockCall(address(vaultFactory), abi.encodeWithSelector(VaultFactory.vaults.selector), abi.encode(new address[](0)));

        // Call an initial trigger, which should pass as no vaults or staked users
        // are set up for the test.
        treasury.endEpoch();

        // Calling the epoch again should result in a reversion as we have not
        // respected the enforced timelock.
        vm.expectRevert(abi.encodeWithSelector(EpochTimelocked.selector, block.timestamp + 7 days));
        treasury.endEpoch();

        // After moving forwards 7 days, we can now successfully end another epoch
        vm.warp(block.timestamp + 7 days);
        treasury.endEpoch();
    }

    function test_CanHandleEpochStressTest() public {
        uint vaultCount = 10;
        uint stakerCount = 50;

        // Set our required internal contracts
        treasury.setGaugeWeightVoteContract(address(gaugeWeightVote));
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Set our sample size of the GWV and to retain 50% of {Treasury} yield
        gaugeWeightVote.setSampleSize(5);
        treasury.setRetainedTreasuryYieldPercentage(10000);

        // Prevent the {VaultFactory} from trying to transfer tokens when registering the mint
        vm.mockCall(address(vaultFactory), abi.encodeWithSelector(VaultFactory.registerMint.selector), abi.encode(''));

        // Set a specific amount of rewards that our {Treasury} has generated to ensure
        // that we generate sufficient yield for the GWV snapshot. For this to work, we
        // need to mint the same amount of FLOOR into the {Treasury} that will be
        // transferred to the {RewardsLedger} when snapshot-ed.
        floor.mint(address(treasury), 1000 ether);

        // Set the {Treasury} to claim 100 {FLOOR} tokens
        vm.mockCall(address(treasury), abi.encodeWithSelector(Treasury._claimTreasuryFloor.selector), abi.encode(100 ether));

        // Mock our Voting mechanism to unlock unlimited user votes without backing
        vm.mockCall(
            address(gaugeWeightVote), abi.encodeWithSelector(GaugeWeightVote.userVotesAvailable.selector), abi.encode(type(uint).max)
        );

        // Mock pending deposits migration (ignore)
        vm.mockCall(address(vaultFactory), abi.encodeWithSelector(Vault.migratePendingDeposits.selector), abi.encode(''));

        // Mock our vaults response (our {VaultFactory} has a hardcoded address(8) when we
        // set up the {Treasury} contract).
        address[] memory vaults = new address[](vaultCount);
        VaultXToken[] memory vaultXTokens = new VaultXToken[](vaultCount);
        address payable[] memory stakers = utilities.createUsers(stakerCount);

        // Loop through our mocked vaults to mint tokens
        for (uint i; i < vaultCount; ++i) {
            // Approve a unique collection
            address collection = address(uint160(uint(vaultCount + i)));
            collectionRegistry.approveCollection(collection);

            // Deploy our vault
            (, vaults[i]) = vaultFactory.createVault('Test Vault', approvedStrategy, _strategyInitBytes(), collection);
            vaultXTokens[i] = VaultXToken(Vault(vaults[i]).xToken());

            // Set up a mock that will set rewards to be a static amount of ether
            vm.mockCall(vaults[i], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(1 ether)));
            // vm.mockCall(vaults[i], abi.encodeWithSelector(NFTXInventoryStakingStrategy.totalRewardsGenerated.selector), abi.encode(uint(1 ether)));

            // Set a list of stakers against the vault by giving them xToken
            vm.startPrank(vaults[i]);
            for (uint j; j < stakerCount; ++j) {
                vaultXTokens[i].mint(stakers[j], 10 ether);

                // Cast votes from this user against the vault collection
                gaugeWeightVote.vote(collection, 1 ether);
            }
            vm.stopPrank();
        }

        // Trigger our epoch end and pray to the gas gods
        treasury.endEpoch();
    }

    /**
     * ...
     */
    function _strategyInitBytes() internal pure returns (bytes memory) {
        return abi.encode(
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _underlyingToken
            0x08765C76C758Da951DC73D3a8863B34752Dd76FB, // _yieldToken
            0x3E135c3E981fAe3383A5aE0d323860a34CfAB893  // _inventoryStaking
        );
    }
}
