// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NFTXInventoryStakingStrategyTest is FloorTest {
    NFTXInventoryStakingStrategy strategy;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_126_124;

    // NFTX DAO - Holds 50.242376308170344638 $PUNK at block
    address testUser = 0xaA29881aAc939A025A3ab58024D7dd46200fB93D;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        // Set up our pricing executor
        strategy = new NFTXInventoryStakingStrategy();
        strategy.initialize(
            bytes32('PUNK Strategy'),
            0, // Strategy ID
            abi.encode(
                0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _underlyingToken
                0x08765C76C758Da951DC73D3a8863B34752Dd76FB, // _yieldToken
                0x3E135c3E981fAe3383A5aE0d323860a34CfAB893 // _inventoryStaking
            )
        );
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'PUNK Strategy');
    }

    /**
     * Our yield token should be the xToken that is defined by the
     * NFTX InventoryStaking contract.
     */
    function test_CanGetYieldToken() public {
        assertEq(strategy.yieldToken(), 0x08765C76C758Da951DC73D3a8863B34752Dd76FB);
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
        assertEq(strategy.underlyingToken(), 0x269616D549D7e8Eaa82DFb17028d0B212D11232A);
    }

    /**
     *
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * This should return an xToken that is stored in the strategy.
     */
    function test_CanDepositToInventoryStaking() public {
        vm.startPrank(testUser);

        // Start with no deposits
        assertEq(strategy.deposits(), 0);

        // Confirm our account has a balance of the underlying token
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(testUser), 50242376308170344638);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(testUser), 0);

        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(strategy.underlyingToken()).approve(address(strategy), 1 ether);
        _deposit(strategy.underlyingToken(), 1 ether);

        assertEq(IERC20(strategy.underlyingToken()).balanceOf(testUser), 49242376308170344638);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(testUser), 0);

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 967780757975035829);

        assertEq(strategy.deposits(), 1 ether);

        vm.stopPrank();
    }

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function test_CannotDepositZeroValue() public {
        address token = strategy.underlyingToken();

        vm.expectRevert(CannotDepositZeroAmount.selector);
        vm.prank(testUser);
        _deposit(token, 0);
    }

    /**
     * We need to be able to claim all pending rewards from the NFTX
     * {InventoryStaking} contract. These should be put in the strategy
     * contract.
     */
    function test_CanWithdraw() public {
        vm.startPrank(testUser);

        // We first need to deposit
        IERC20(strategy.underlyingToken()).approve(address(strategy), 1 ether);
        uint[] memory depositAmounts = _deposit(strategy.underlyingToken(), 1 ether);
        uint depositAmount = depositAmounts[0];

        // If we try to claim straight away, our user will be locked
        address token = strategy.underlyingToken();
        vm.expectRevert('User locked');
        _withdraw(token, 0.5 ether);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Confirm that we cannot claim more than our token balance
        vm.expectRevert('ERC20: burn amount exceeds balance');
        _withdraw(token, depositAmount + 1);

        // We can now claim rewards via the strategy that will eat away from our
        // deposit. For this test we will burn 0.5 xToken (yieldToken) to claim
        // back our underlying token.
        _withdraw(token, 0.5 ether);

        // The strategy should now hold token
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 467780757975035829);

        vm.stopPrank();
    }

    /**
     * Even when we have no rewards to claim, we should still be able
     * to make the request but we just expect a 0 value to be returned.
     */
    function test_CannotClaimZeroRewards() public {
        address token = strategy.underlyingToken();

        vm.expectRevert(CannotWithdrawZeroAmount.selector);
        vm.prank(testUser);
        _withdraw(token, 0);
    }

    /**
     * We should be able to fully exit our position, having the all of
     * our vault ERC20 tokens returned and the xToken burnt from the
     * strategy.
     */
    function test_CanFullyExitPosition() public {
        vm.startPrank(testUser);

        // We first need to deposit
        IERC20(strategy.underlyingToken()).approve(address(strategy), 1 ether);
        uint[] memory depositAmounts = _deposit(strategy.underlyingToken(), 1 ether);
        uint depositAmount = depositAmounts[0];

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // We can now exit via the strategy. This will burn all of our xToken and
        // we will just have our `underlyingToken` back in the strategy.
        _withdraw(strategy.underlyingToken(), depositAmount);

        // The strategy should now hold token and xToken. However, we need to accomodate
        // for the dust bug in the InventoryStaking zap that leaves us missing 1 wei.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0);

        vm.stopPrank();
    }

    /**
     * When we have rewards available we want to be able to determine
     * the token amount without needing to process a write call. This
     * will mean a much lower gas usage.
     */
    function test_CanDetermineRewardsAvailableAndClaim() public {
        vm.startPrank(testUser);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(strategy.underlyingToken()).approve(address(strategy), 5 ether);
        _deposit(strategy.underlyingToken(), 5 ether);

        // Skip some time for the NFTX lock to expire
        skip(2592001);

        // Check the balance directly that should be claimable
        uint startRewardsAvailable = strategy.rewardsAvailable(strategy.underlyingToken());
        assertEq(startRewardsAvailable, 0);

        // Generate some rewards by dealing xToken to our user
        deal(strategy.yieldToken(), address(strategy), 8 ether);

        // Check the balance directly that should be claimable
        uint rewardsAvailable = strategy.rewardsAvailable(strategy.underlyingToken());
        assertEq(rewardsAvailable, 3161096210124820848);

        // Get the {Treasury} starting balance of the reward token
        uint treasuryStartBalance = IERC20(strategy.underlyingToken()).balanceOf(users[1]);
        assertEq(treasuryStartBalance, 0);

        vm.stopPrank();

        // Claim our rewards
        vm.prank(users[1]);
        strategy.claimRewards();

        vm.startPrank(testUser);

        // Check the balance directly that should be claimable
        uint newRewardsAvailable = strategy.rewardsAvailable(strategy.underlyingToken());
        assertEq(newRewardsAvailable, 0);

        // Confirm that the {Treasury} has received the rewards
        // TODO: This should always go to Treasury, not the caller
        uint treasuryEndBalance = IERC20(strategy.underlyingToken()).balanceOf(users[1]);
        assertEq(treasuryEndBalance, 3161096210124820848);

        vm.stopPrank();
    }

    /**
     * Even when we have no rewards pending to be claimed, we don't want
     * the transaction to be reverted, but instead just return zero.
     */
    function test_CanDetermineRewardsAvailableWhenZero() public {
        assertEq(strategy.rewardsAvailable(strategy.underlyingToken()), 0);
    }

    /**
     * When we have generated yield we want to be sure that our helper
     * function returns the correct value.
     */
    function test_CanCalculateTotalRewardsGenerated() public {
        assertEq(strategy.totalRewardsGenerated(strategy.underlyingToken()), 0);
    }

    /**
     * Helper function call to make a deposit.
     */
    function _deposit(address token, uint amount) internal returns (uint[] memory) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint[] memory amounts = new uint[](1);
        amounts[0] = amount;

        return strategy.deposit(tokens, amounts);
    }

    /**
     * Helper function call to make a deposit.
     */
    function _withdraw(address token, uint amount) internal returns (uint[] memory) {
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint[] memory amounts = new uint[](1);
        amounts[0] = amount;

        return strategy.withdraw(tokens, amounts);
    }

}
