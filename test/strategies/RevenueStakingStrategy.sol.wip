// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract RevenueStakingStrategyTest is FloorTest {
    RevenueStakingStrategy strategy;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_126_124;

    // NFTX DAO - Holds 50.242376308170344638 $PUNK at block
    address testUser = 0xaA29881aAc939A025A3ab58024D7dd46200fB93D;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        address[] memory tokens = new address[](2);
        tokens[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;  // WETH
        tokens[1] = 0x269616D549D7e8Eaa82DFb17028d0B212D11232A;  // PUNK

        // Set up our pricing executor
        strategy = new RevenueStakingStrategy(bytes32('Uniswap WETH/PUNK'));
        strategy.initialize(
            0, // Vault ID
            testUser, // Vault Address (set to our testUser so that it can call strategy methods direct)
            abi.encode(tokens)
        );
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'Uniswap WETH/PUNK');
    }

    /**
     * ..
     */
    function test_CanGetTokens() public {
        address[] memory tokens = strategy.tokens();
        assertEq(tokens[0], 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(tokens[1], 0x269616D549D7e8Eaa82DFb17028d0B212D11232A);
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
    function test_CanDepositToRevenueStaking() public {
        vm.startPrank(testUser);

        // Start with no deposits
        assertEq(strategy.totalRewardsGenerated(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 0);
        assertEq(strategy.totalRewardsGenerated(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 0);
        assertEq(strategy.unmintedRewards(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 0);
        assertEq(strategy.unmintedRewards(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 0);

        assertEq(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(testUser), 78400000000000000000);
        assertEq(IERC20(0x269616D549D7e8Eaa82DFb17028d0B212D11232A).balanceOf(testUser), 50242376308170344638);

        assertEq(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(address(strategy)), 0);
        assertEq(IERC20(0x269616D549D7e8Eaa82DFb17028d0B212D11232A).balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(address(strategy), 1 ether);
        IERC20(0x269616D549D7e8Eaa82DFb17028d0B212D11232A).approve(address(strategy), 1 ether);

        strategy.deposit(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 1 ether);
        strategy.deposit(0x269616D549D7e8Eaa82DFb17028d0B212D11232A, 1 ether);

        assertEq(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(testUser), 77400000000000000000);
        assertEq(IERC20(0x269616D549D7e8Eaa82DFb17028d0B212D11232A).balanceOf(testUser), 49242376308170344638);

        assertEq(IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(address(strategy)), 1000000000000000000);
        assertEq(IERC20(0x269616D549D7e8Eaa82DFb17028d0B212D11232A).balanceOf(address(strategy)), 1000000000000000000);

        assertEq(strategy.totalRewardsGenerated(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 1000000000000000000);
        assertEq(strategy.totalRewardsGenerated(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 1000000000000000000);

        assertEq(strategy.unmintedRewards(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 1000000000000000000);
        assertEq(strategy.unmintedRewards(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 1000000000000000000);

        // Register the mint
        strategy.registerMint(address(this), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 0.5 ether);

        assertEq(strategy.totalRewardsGenerated(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 1000000000000000000);
        assertEq(strategy.totalRewardsGenerated(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 1000000000000000000);

        assertEq(strategy.unmintedRewards(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), 0.5 ether);
        assertEq(strategy.unmintedRewards(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 1 ether);

        vm.stopPrank();
    }

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function test_CannotDepositZeroValue() public {
        vm.startPrank(testUser);
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 0);

        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit(0x269616D549D7e8Eaa82DFb17028d0B212D11232A, 0);
        vm.stopPrank();
    }

    function test_CannotDepositUnknownToken() public {
        vm.startPrank(testUser);
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit(address(0), 0);
        vm.stopPrank();
    }

    /**
     * Even when we have no rewards pending to be claimed, we don't want
     * the transaction to be reverted, but instead just return zero.
     */
    function test_CanDetermineRewardsAvailableWhenZero() public {
        assertEq(strategy.rewardsAvailable(0x269616D549D7e8Eaa82DFb17028d0B212D11232A), 0);
    }

}
