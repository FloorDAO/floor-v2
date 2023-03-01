// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NFTXLiquidityStakingStrategy} from '@floor/strategies/NFTXLiquidityStakingStrategy.sol';

import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NFTXLiquidityStakingStrategyTest is FloorTest {
    NFTXLiquidityStakingStrategy strategy;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_133_601;

    // Holds 0.02963115425863499 SLP at block
    address testUser = 0x5cC3cB20B2531C4A6d59Bf37aac8aCD0e8D099d3;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        // Set up our pricing executor
        strategy = new NFTXLiquidityStakingStrategy(bytes32('PUNK Liquidity Vault'));
        strategy.initialize(
            0, // Vault ID
            testUser, // Vault Address (set to our testUser so that it can call strategy methods direct)
            abi.encode(
                0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _pool
                0x0463a06fBc8bF28b3F120cd1BfC59483F099d332, // _underlyingToken
                0xFB2f1C0e0086Bcef24757C3b9bfE91585b1A280f, // _yieldToken
                0x688c3E4658B5367da06fd629E41879beaB538E37 // _liquidityStaking
            )
        );
    }

    /**
     *
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'PUNK Liquidity Vault');
    }

    /**
     * Our yield token should be the xToken that is defined by the
     * NFTX InventoryStaking contract.
     */
    function test_CanGetYieldToken() public {
        assertEq(strategy.yieldToken(), 0xFB2f1C0e0086Bcef24757C3b9bfE91585b1A280f);
    }

    /**
     * Our underlying token in our strategy is the NFTX ERC20 vault
     * token. This is normally be obtained through providing the NFT
     * to be deposited into the vault. We only want to accept the
     * already converted ERC20 vault token.
     *
     * This can be done through a zap, or just handled directly on
     * NFTX. This removes our requirement to inform users of the risks
     * that NFTX can impose.
     */
    function test_CanGetUnderlyingToken() public {
        assertEq(strategy.underlyingToken(), 0x0463a06fBc8bF28b3F120cd1BfC59483F099d332);
    }

    /**
     *
     */
    function test_CanGetPool() public {
        assertEq(strategy.pool(), 0x269616D549D7e8Eaa82DFb17028d0B212D11232A);
    }

    /**
     *
     */
    function test_CanGetVaultId() public {
        assertEq(strategy.vaultId(), 0);
    }

    /**
     * This should return an xToken that is stored in the strategy.
     */
    function test_CanDepositToLiquidityStaking() public {
        vm.startPrank(testUser);

        // Start with no deposits
        assertEq(strategy.deposits(), 0);

        // Confirm our account has a balance of the underlying token
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(testUser), 29631154258634990);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(testUser), 0);

        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(strategy.underlyingToken()).approve(address(strategy), 20000000000000000);
        strategy.deposit(20000000000000000);

        // The user should now hold 1e18 less underlying token, whilst still holding no yield
        // token as this will have been sent to the strategy.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(testUser), 9631154258634990);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(testUser), 0);

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 20000000000000000);

        assertEq(strategy.deposits(), 20000000000000000);

        vm.stopPrank();
    }

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function test_CannotDepositZeroValue() public {
        vm.expectRevert(CannotDepositZeroAmount.selector);
        vm.prank(testUser);
        strategy.deposit(0);
    }

    /**
     * We need to be able to claim all pending rewards from the NFTX
     * {LiquidityStaking} contract. These should be put in the strategy
     * contract.
     *
     * TODO: New Flow
     */
    function _test_CanWithdraw() public {
        vm.startPrank(testUser);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(strategy.underlyingToken()).approve(address(strategy), 20000000000000000);
        strategy.deposit(20000000000000000);

        vm.stopPrank();

        // Test user then makes a buy from the vault
        // Holds 24.323478926295584311 PUNK token at block
        vm.startPrank(0x08765C76C758Da951DC73D3a8863B34752Dd76FB);

        // IERC20(strategy.pool()).approve(strategy.pool(), type(uint).max);
        uint[] memory tokenIds = new uint256[](0);
        INFTXVault(strategy.pool()).redeem(1, tokenIds);

        vm.stopPrank();

        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 20000000000000000);

        // This should give pending yield to claim rewards
        assertEq(strategy.rewardsAvailable(), 1878746779354);

        // Our rewards are paid in vault token
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 20000000000000000);
        assertEq(IERC20(strategy.pool()).balanceOf(address(strategy)), 1878746779354);
    }

    /**
     * Even when we have no rewards to claim, we should still be able
     * to make the request but we just expect a 0 value to be returned.
     */
    function test_CannotClaimZeroRewards() public {
        vm.expectRevert(CannotWithdrawZeroAmount.selector);
        vm.prank(testUser);
        strategy.withdraw(0);
    }

    /**
     * We should be able to fully exit our position, having the all of
     * our vault ERC20 tokens returned and the xToken burnt from the
     * strategy.
     */
    function testCanFullyExitPosition() public {}

    /**
     * If we have multiple users with staked positions, a user cannot
     * exit to a value more than they have staked. This has to be
     * enforced to prevent other user's xTokens being taken. We expect
     * a revert in this case.
     *
     * This will be done via the vault.
     */
    function testCannotExitBeyondPosition() public {}

    /**
     * If we don't have a stake in the {InventoryStaking} contract and
     * we try to exit our (non-existant) position then we should expect
     * a revert.
     *
     * This will be done via the vault.
     */
    function testCannotExitPositionWithZeroStake() public {}

    /**
     * When we have rewards available we want to be able to determine
     * the token amount without needing to process a write call. This
     * will mean a much lower gas usage.
     */
    function testCanDetermineRewardsAvailable() public {}

    /**
     * Even when we have no rewards pending to be claimed, we don't want
     * the transaction to be reverted, but instead just return zero.
     */
    function testCanDetermineRewardsAvailableWhenZero() public {
        assertEq(strategy.rewardsAvailable(), 0);
    }

    /**
     * When we have generated yield we want to be sure that our helper
     * function returns the correct value.
     */
    function testCanCalculateTotalRewardsGenerated() public {
        assertEq(strategy.totalRewardsGenerated(), 0);
    }
}
