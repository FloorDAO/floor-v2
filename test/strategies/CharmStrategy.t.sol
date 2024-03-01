// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {CharmStrategy} from '@floor/strategies/CharmStrategy.sol';
import {CannotDepositZeroAmount} from '@floor/utils/Errors.sol';
import {Treasury} from '@floor/Treasury.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../utilities/Environments.sol';


contract CharmStrategyTest is FloorTest {
    /// The mainnet contract address of our Uniswap Position Manager
    address internal constant CHARM_VAULT = 0x381e7287EB6DF7C74B52661f91b1B02269144198;

    /// Tokens that we can test with (WETH is already defined in `FloorTest`)
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (6 decimals)

    /// Define our approved collection
    address internal constant APPROVED_COLLECTION = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 19_289_378;

    /// Store our internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;
    CharmStrategy strategy;

    /// Store our strategy ID
    uint strategyId;

    /// Store our strategy implementation address
    address strategyImplementation;

    /// Store a {Treasury} wallet address
    address treasury;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();

        // Deploy our strategy implementation
        strategyImplementation = address(new CharmStrategy());

        // Create our {CollectionRegistry} and approve our collections
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        collectionRegistry.approveCollection(APPROVED_COLLECTION);

        // Create our {StrategyRegistry} and approve our implementation
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        strategyRegistry.approveStrategy(strategyImplementation, true);

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry)
        );

        // Deploy our {Treasury} and assign it to our {StrategyFactory}
        treasury = address(new Treasury(address(authorityRegistry), address(1), WETH));
        strategyFactory.setTreasury(treasury);

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('USDC/WETH Charm Vault'),
            strategyImplementation,
            abi.encode(CHARM_VAULT, address(this)),
            APPROVED_COLLECTION
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = CharmStrategy(_strategy);
        strategyId = _strategyId;
    }

    function test_CanGetVaultInformation() public {
        assertEq(address(strategy.charmVault()), CHARM_VAULT);

        assertEq(address(strategy.token0()), USDC);
        assertEq(address(strategy.token1()), WETH);

        assertEq(strategy.name(), 'USDC/WETH Charm Vault');
        assertEq(strategy.strategyId(), 0);

        (address[] memory tokens) = strategy.validTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], USDC);
        assertEq(tokens[1], WETH);
    }

    function test_CanDeposit(uint _amount0Desired, uint _amount1Desired) public {
        // Bind our values around realistic amounts
        _amount0Desired = bound(_amount0Desired, 100_000000, 100000_000000);
        _amount1Desired = bound(_amount1Desired, 1 ether, 100 ether);

        // Make our deposit
        (uint shares, uint amount0, uint amount1) = _deposit(_amount0Desired, _amount1Desired);

        // Shares != 0
        assertFalse(shares == 0);

        // 0 < amount0 < _amount0Desired
        assertGt(amount0, 0);
        assertLe(amount0, _amount0Desired);

        // 0 < amount1 < _amount1Desired
        assertGt(amount1, 0);
        assertLe(amount1, _amount1Desired);
    }

    function test_CanMakeMultipleDeposits() public {
        uint _amount0Desired = 100000_000000;
        uint _amount1Desired = 10 ether;

        // Make our deposit
        _deposit(_amount0Desired, _amount1Desired);

        // Make a subsequent deposit that would normally revert as not enough time has
        // passed to action a rebalance. However, we catch this exception and silence it.
        _deposit(_amount0Desired, _amount1Desired);

        // We can then skip ahead and make another successful deposit
        vm.warp(block.timestamp + strategy.charmVault().period() + 1);
        _deposit(_amount0Desired, _amount1Desired);
    }

    function test_CannotDepositZeroVault() public {
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit(0, 0, 0, 0);
    }

    function test_CanWithdraw(uint _shares) public {
        // Make a sizeable deposit
        (uint shares,,) = _deposit(100000_000000, 100 ether);

        // Ensure that the amount of shares we want to withdraW from is more than zero,
        // and that it is not more than the amount of shares we have available.
        _shares = bound(_shares, shares / 100, shares);

        // Capture our start balance of the {Treasury}
        uint token0Amount = IERC20(USDC).balanceOf(address(treasury));
        uint token1Amount = IERC20(WETH).balanceOf(address(treasury));

        // Attempt to withdraw from our position. For the purposes of this test we
        strategyFactory.withdraw(
            strategyId,
            abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, _shares)
        );

        assertGt(IERC20(USDC).balanceOf(address(treasury)), token0Amount);
        assertGt(IERC20(WETH).balanceOf(address(treasury)), token1Amount);
    }

    function test_CannotWithdrawMoreThanPosition() public {
        // Make a sizeable deposit
        (uint shares,,) = _deposit(100000_000000, 100 ether);

        // Attempt to withdraw from our position, referncing more shares than owned
        vm.expectRevert();
        strategyFactory.withdraw(
            strategyId,
            abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, shares + 1)
        );
    }

    function test_CanWithdrawPercentageWithoutOutput() public {
        // We don't have any validation on our withdraw percentage call, as there is no logic
        // to be processed.
        strategyFactory.withdrawPercentage(address(strategy), 100_00);
    }

    function test_CanGetAvailable() public {
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        // Ensure we receive both expected tokens
        assertEq(tokens.length, 2);
        assertEq(tokens[0], USDC);
        assertEq(tokens[1], WETH);

        // Ensure that both tokens show zero amount withdrawn
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 414105120);
        assertEq(amounts[1], 226974701814370686);
    }

    function test_CanHarvestWithoutOutput() public {
        vm.prank(address(strategyFactory));
        strategy.harvest(address(treasury));
    }

    function test_CanCallRebalance() public {
        // Confirm that we have the expected address set
        assertEq(strategy.rebalancer(), address(this));

        // We can call rebalance with our approved address
        strategy.rebalance();
    }

    function test_CannotCallRebalanceWithInvalidCaller() public {
        // Try and rebalance the strategy
        vm.expectRevert('Invalid caller');
        vm.prank(address(1));
        strategy.rebalance();
    }

    function _deposit(uint _amount0Desired, uint _amount1Desired) internal returns (uint shares_, uint amount0_, uint amount1_) {
        // Deal sufficient tokens to action our deposit
        deal(USDC, address(this), _amount0Desired);
        deal(WETH, address(this), _amount1Desired);

        // Approve our strategy to use our tokens
        IERC20(USDC).approve(address(strategy), type(uint).max);
        IERC20(WETH).approve(address(strategy), type(uint).max);

        // Make our deposit with no minimum values specified
        (shares_, amount0_, amount1_) = strategy.deposit(_amount0Desired, _amount1Desired, 0, 0);
    }

}
