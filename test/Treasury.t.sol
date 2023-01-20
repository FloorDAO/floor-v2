// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/mocks/ERC20Mock.sol';

import './mocks/erc/ERC721Mock.sol';
import './mocks/erc/ERC1155Mock.sol';
import './mocks/PricingExecutor.sol';

import '../src/contracts/collections/CollectionRegistry.sol';
import {veFLOOR} from '../src/contracts/tokens/VeFloor.sol';
import '../src/contracts/tokens/Floor.sol';
import '../src/contracts/strategies/StrategyRegistry.sol';
import '../src/contracts/vaults/Vault.sol';
import '../src/contracts/vaults/VaultFactory.sol';
import '../src/contracts/RewardsLedger.sol';
import '../src/contracts/Treasury.sol';

import '../src/interfaces/vaults/Vault.sol';
import '../src/interfaces/voting/GaugeWeightVote.sol';

import './utilities/Environments.sol';

contract TreasuryTest is FloorTest {
    address VAULT_FACTORY = address(10);
    address VOTE_CONTRACT = address(12);

    address alice;
    address bob;
    address carol;

    FLOOR floor;
    veFLOOR veFloor;
    ERC20Mock erc20;
    ERC721Mock erc721;
    ERC1155Mock erc1155;
    CollectionRegistry collectionRegistry;
    RewardsLedger rewards;
    StrategyRegistry strategyRegistry;
    Treasury treasury;

    PricingExecutorMock pricingExecutorMock;

    constructor() {
        // Set up our mock pricing executor
        pricingExecutorMock = new PricingExecutorMock();

        // Set up our {Floor} token
        floor = new FLOOR(address(authorityRegistry));
        veFloor = new veFLOOR('veFloor', 'veFLOOR', address(authorityRegistry));

        // Set up a fake ERC20 token that we can test with. We use the {Floor} token
        // contract as a base as this already implements IERC20. We have no initial
        // balance.
        erc20 = new ERC20Mock();
        erc721 = new ERC721Mock();
        erc1155 = new ERC1155Mock();

        // Set up our registries
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Set up our {Treasury}
        treasury = new Treasury(
            address(authorityRegistry),
            address(collectionRegistry),  // address _collectionRegistry,
            address(strategyRegistry),    // address _strategyRegistry,
            VAULT_FACTORY,
            address(floor)
        );

        // Set up our {RewardsLedger}
        rewards = new RewardsLedger(
            address(authorityRegistry),
            address(floor),
            address(treasury),
            address(0)  // Staking
        );

        // Create our test users
        (alice, bob, carol) = (users[0], users[1], users[2]);

        // Give our {Treasury} contract roles to manage (mint) Floor tokens
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(treasury));
        authorityRegistry.grantRole(authorityControl.REWARDS_MANAGER(), address(treasury));

        // Give Bob the `TREASURY_MANAGER` role so that he can withdraw if needed
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), bob);

        // Grant our {RewardsLedger} the required roles
        authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(rewards));
        authorityRegistry.grantRole(authorityControl.STAKING_MANAGER(), address(rewards));
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
        vm.expectRevert('Account does not have role');
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
        vm.expectRevert('Cannot mint zero Floor');
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

        vm.expectRevert('Account does not have role');
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

        vm.expectRevert('Account does not have role');
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
        vm.expectRevert('Account does not have role');
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
        vm.expectRevert('Account does not have role');
        vm.prank(carol);
        treasury.withdrawERC1155(bob, address(erc1155), 1, 3);
    }

    /**
     * We want to ensure that we can update the address of the {RewardsLedger}
     * contract.
     */
    function test_CanSetRewardsLedgerContract() public {
        assertEq(address(treasury.rewardsLedger()), address(0));

        treasury.setRewardsLedgerContract(address(1));
        assertEq(address(treasury.rewardsLedger()), address(1));
    }

    /**
     * We will need to validate the {RewardsLedger} address to ensure that we
     * don't pass a `NULL` address value. We expect a revert.
     */
    function test_CannotSetRewardsLedgerContractNullValue() public {
        vm.expectRevert('Cannot set to null address');
        treasury.setRewardsLedgerContract(address(0));
    }

    /**
     * Only a `TreasuryManager` should be able to update our {RewardsLedger}
     * address. If another user role calls this function then we expect it to
     * be reverted.
     */
    function test_CannotSetRewardsLedgerContractWithoutPermissions() public {
        vm.expectRevert('Account does not have role');
        vm.prank(alice);
        treasury.setRewardsLedgerContract(address(1));
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
        vm.expectRevert('Cannot set to null address');
        treasury.setGaugeWeightVoteContract(address(0));
    }

    function test_CannotSetGaugeWeightVoteContractWithoutPermissions() public {
        vm.expectRevert('Account does not have role');
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

        vm.expectRevert('Percentage too high');
        treasury.setRetainedTreasuryYieldPercentage(percentage);
    }

    function test_CannotSetRetainedTreasuryYieldPercentageWithoutPermissions() public {
        vm.expectRevert('Account does not have role');
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
        vm.expectRevert('No pricing executor set');
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
        vm.expectRevert('Cannot set to null address');
        treasury.setPricingExecutor(address(0));
    }

    function test_CannotSetPricingExecutorWithoutPermissions() public {
        vm.expectRevert('Account does not have role');
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
        treasury.setRewardsLedgerContract(address(rewards));
        treasury.setGaugeWeightVoteContract(address(12));
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Mock our vaults response (our {VaultFactory} has a hardcoded address(8) when we
        // set up the {Treasury} contract).
        address[] memory vaults = new address[](5);
        (vaults[0], vaults[1], vaults[2], vaults[3], vaults[4]) =
            (address(5), address(6), address(7), address(8), address(9));

        // Create a unique set of test users
        users = utilities.createUsers(8, 0);

        vm.mockCall(VAULT_FACTORY, abi.encodeWithSelector(VaultFactory.vaults.selector), abi.encode(vaults));

        // Approve our vault collections
        collectionRegistry.approveCollection(address(1));
        collectionRegistry.approveCollection(address(2));
        collectionRegistry.approveCollection(address(3));
        collectionRegistry.approveCollection(address(4));

        // Mock our rewards yield claim amount. For simplicity of future calculations, I've made
        // these the same as the number of users that have (mock) staked against to it
        vm.mockCall(vaults[0], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(8 ether)));
        vm.mockCall(vaults[1], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(1 ether)));
        vm.mockCall(vaults[2], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(5 ether)));
        vm.mockCall(vaults[3], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(6 ether)));
        vm.mockCall(vaults[4], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(4 ether)));

        // Mock our collection for each vault
        vm.mockCall(vaults[0], abi.encodeWithSelector(IVault.collection.selector), abi.encode(address(1)));
        vm.mockCall(vaults[1], abi.encodeWithSelector(IVault.collection.selector), abi.encode(address(2)));
        vm.mockCall(vaults[2], abi.encodeWithSelector(IVault.collection.selector), abi.encode(address(2)));
        vm.mockCall(vaults[3], abi.encodeWithSelector(IVault.collection.selector), abi.encode(address(3)));
        vm.mockCall(vaults[4], abi.encodeWithSelector(IVault.collection.selector), abi.encode(address(4)));

        // Mock our vault shares
        address[] memory shareUsers = new address[](7);
        uint[] memory userShares = new uint[](7);
        (shareUsers[0], shareUsers[1], shareUsers[2], shareUsers[3], shareUsers[4], shareUsers[5], shareUsers[6]) =
            (address(treasury), users[0], users[1], users[2], users[3], users[4], users[5]);
        (userShares[0], userShares[1], userShares[2], userShares[3], userShares[4], userShares[5], userShares[6]) =
            (3000, 1000, 1500, 1500, 2000, 500, 250);
        vm.mockCall(vaults[0], abi.encodeWithSelector(Vault.shares.selector), abi.encode(shareUsers, userShares));

        shareUsers = new address[](1);
        userShares = new uint[](1);
        shareUsers[0] = address(treasury);
        userShares[0] = 10000;
        vm.mockCall(vaults[1], abi.encodeWithSelector(Vault.shares.selector), abi.encode(shareUsers, userShares));

        shareUsers = new address[](5);
        userShares = new uint[](5);
        (shareUsers[0], shareUsers[1], shareUsers[2], shareUsers[3], shareUsers[4]) =
            (address(treasury), users[3], users[4], users[6], users[7]);
        (userShares[0], userShares[1], userShares[2], userShares[3], userShares[4]) = (2000, 2000, 2500, 2500, 1000);
        vm.mockCall(vaults[2], abi.encodeWithSelector(Vault.shares.selector), abi.encode(shareUsers, userShares));

        shareUsers = new address[](6);
        userShares = new uint[](6);
        (shareUsers[0], shareUsers[1], shareUsers[2], shareUsers[3], shareUsers[4], shareUsers[5]) =
            (address(treasury), users[0], users[2], users[4], users[6], users[7]);
        (userShares[0], userShares[1], userShares[2], userShares[3], userShares[4], userShares[5]) =
            (2000, 2500, 2500, 1000, 1000, 1000);
        vm.mockCall(vaults[3], abi.encodeWithSelector(Vault.shares.selector), abi.encode(shareUsers, userShares));

        shareUsers = new address[](4);
        userShares = new uint[](4);
        (shareUsers[0], shareUsers[1], shareUsers[2], shareUsers[3]) = (address(treasury), users[5], users[6], users[7]);
        (userShares[0], userShares[1], userShares[2], userShares[3]) = (2500, 2500, 2500, 2500);
        vm.mockCall(vaults[4], abi.encodeWithSelector(Vault.shares.selector), abi.encode(shareUsers, userShares));

        // Mock vault share recalculation (ignore)
        vm.mockCall(vaults[0], abi.encodeWithSelector(Vault.recalculateVaultShare.selector), abi.encode(''));
        vm.mockCall(vaults[1], abi.encodeWithSelector(Vault.recalculateVaultShare.selector), abi.encode(''));
        vm.mockCall(vaults[2], abi.encodeWithSelector(Vault.recalculateVaultShare.selector), abi.encode(''));
        vm.mockCall(vaults[3], abi.encodeWithSelector(Vault.recalculateVaultShare.selector), abi.encode(''));
        vm.mockCall(vaults[4], abi.encodeWithSelector(Vault.recalculateVaultShare.selector), abi.encode(''));

        // Mock our vote distribution
        shareUsers = new address[](5);
        userShares = new uint[](5);
        (shareUsers[0], shareUsers[1], shareUsers[2], shareUsers[3], shareUsers[4]) =
            (users[0], users[2], users[3], users[4], users[6]);
        (userShares[0], userShares[1], userShares[2], userShares[3], userShares[4]) =
            (4 ether, 3 ether, 1 ether, 1 ether, 3 ether);
        vm.mockCall(
            VOTE_CONTRACT,
            abi.encodeWithSelector(IGaugeWeightVote.snapshot.selector),
            abi.encode(shareUsers, userShares)
        );

        // Trigger our epoch end
        treasury.endEpoch();

        // Confirm the amount allocated to each user
        assertEq(rewards.available(address(treasury), address(floor)), 0);
        assertEq(rewards.available(users[0], address(floor)), 234 ether);
        assertEq(rewards.available(users[1], address(floor)), 120 ether);
        assertEq(rewards.available(users[2], address(floor)), 273 ether);
        assertEq(rewards.available(users[3], address(floor)), 261 ether);
        assertEq(rewards.available(users[4], address(floor)), 226 ether);
        assertEq(rewards.available(users[5], address(floor)), 120 ether);
        assertEq(rewards.available(users[6], address(floor)), 288 ether);
        assertEq(rewards.available(users[7], address(floor)), 210 ether);

        // Confirm rewards ledger holds all expected floor to distribute to above users
        assertEq(floor.balanceOf(address(rewards)), 4187929680 ether);
    }

    /**
     * After an epoch has run, there is a minimum wait that must be respected before
     * trying to run it again. If this is not catered for, then we expect a revert.
     */
    function test_CannotCallAnotherEpochWithoutRespectingTimeout() public {
        // Set our required internal contracts
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Mock our VaultFactory call to return no vaults
        vm.mockCall(VAULT_FACTORY, abi.encodeWithSelector(VaultFactory.vaults.selector), abi.encode(new address[](0)));

        // Call an initial trigger, which should pass as no vaults or staked users
        // are set up for the test.
        treasury.endEpoch();

        // Calling the epoch again should result in a reversion as we have not
        // respected the enforced timelock.
        vm.expectRevert('Not enough time since last epoch');
        treasury.endEpoch();

        // After moving forwards 7 days, we can now successfully end another epoch
        vm.warp(block.timestamp + 7 days);
        treasury.endEpoch();
    }

    function test_CanHandleEpochStressTest() public {
        uint vaultCount = 10;
        uint stakerCount = 100;

        // Set our required internal contracts
        treasury.setRewardsLedgerContract(address(rewards));
        treasury.setGaugeWeightVoteContract(address(12));
        treasury.setPricingExecutor(address(pricingExecutorMock));

        // Set up a list of vault shares
        uint[] memory shares = new uint[](stakerCount);
        for (uint j; j < stakerCount;) {
            shares[j] = 10000 / stakerCount;
            unchecked { ++j; }
        }

        // Mock our vaults response (our {VaultFactory} has a hardcoded address(8) when we
        // set up the {Treasury} contract).
        address[] memory vaults = new address[](vaultCount);
        for (uint i; i < vaultCount;) {
            vaults[i] = address(uint160(uint(0 + i)));

            // Approve a unique collection
            collectionRegistry.approveCollection(address(uint160(uint(vaultCount + i))));
            vm.mockCall(vaults[i], abi.encodeWithSelector(IVault.collection.selector), abi.encode(address(uint160(uint(vaultCount + i)))));

            // Set up a mock that will set rewards to be a static amount of ether
            vm.mockCall(vaults[i], abi.encodeWithSelector(Vault.claimRewards.selector), abi.encode(uint(1 ether)));

            // Set a list of stakers against the vault
            vm.mockCall(vaults[i], abi.encodeWithSelector(Vault.shares.selector), abi.encode(utilities.createUsers(stakerCount), shares));

            // Mock vault share recalculation (ignore)
            vm.mockCall(vaults[i], abi.encodeWithSelector(Vault.recalculateVaultShare.selector), abi.encode(''));

            unchecked { ++i; }
        }

        // Mock our VaultFactory call to return no vaults
        vm.mockCall(VAULT_FACTORY, abi.encodeWithSelector(VaultFactory.vaults.selector), abi.encode(vaults));

        // Mock our vote distribution
        vm.mockCall(
            VOTE_CONTRACT,
            abi.encodeWithSelector(IGaugeWeightVote.snapshot.selector),
            abi.encode(utilities.createUsers(stakerCount, 0), shares)
        );

        // Trigger our epoch end and pray to the gas gods
        treasury.endEpoch();
    }

}
