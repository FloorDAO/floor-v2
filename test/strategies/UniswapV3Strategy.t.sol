// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';
import {CannotDepositZeroAmount} from '@floor/utils/Errors.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract UniswapV3StrategyTest is FloorTest {
    /// The mainnet contract address of our Uniswap Position Manager
    address internal constant UNISWAP_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    uint24 internal constant POOL_FEE = 500;

    /// Two tokens that we can test with
    address internal constant TOKEN_A = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (6 decimals)
    address internal constant TOKEN_B = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH (18 decimals)

    /// A user that holds sufficient liquidity of the above tokens
    address internal constant LIQUIDITY_HOLDER = 0x0f294726A2E3817529254F81e0C195b6cd0C834f;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_989_012;

    /// Store our internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    UniswapV3Strategy strategy;

    /// Store our strategy ID
    uint strategyId;

    /// Store a {Treasury} wallet address
    address treasury;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Create our {CollectionRegistry} and approve our collection
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        // Approve our ERC721 collection
        collectionRegistry.approveCollection(0x5Af0D9827E0c53E4799BB226655A1de152A425a5, 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48);
        // Approve our ERC1155 collection
        collectionRegistry.approveCollection(0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313, 0xE97e496E8494232ee128c1a8cAe0b2B7936f3CaA);

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(address(authorityRegistry), address(collectionRegistry));

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('USDC/WETH UV3 Pool'),
            address(new UniswapV3Strategy()),
            abi.encode(
                TOKEN_A,  // address token0
                TOKEN_B,  // address token1
                POOL_FEE,  // uint24 fee
                0,  // uint96 sqrtPriceX96
                -887270,  // int24 tickLower
                887270,  // int24 tickUpper
                address(0),  // address pool
                UNISWAP_POSITION_MANAGER  // address positionManager
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = UniswapV3Strategy(_strategy);
        strategyId = _strategyId;

        // Deal some additional USDC and WETH tokens
        deal(TOKEN_A, LIQUIDITY_HOLDER, 100_000_000000);
        deal(TOKEN_B, LIQUIDITY_HOLDER, 100_000000000000000000);

        // Define a treasury wallet address that we can test against
        treasury = users[1];
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'USDC/WETH UV3 Pool');
    }

    /**
     * Ensures that we have the correct tokens attached to the strategy.
     */
    function test_CanGetTokens() public {
        address[] memory tokens = strategy.validTokens();
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
    }

    /**
     * Ensures that we can correctly find the strategy ID that was deployed with the strategy.
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * Ensure that we can deposit and withdraw against the strategy as expected.
     */
    function test_CanDepositAndWithdraw() public {
        // Confirm our test user's starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(LIQUIDITY_HOLDER), 100000_000000);
        assertEq(IERC20(TOKEN_B).balanceOf(LIQUIDITY_HOLDER), 100_000000000000000000);

        // Confirm our strategies starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 0);

        // Before our first deposit, our tokenId should be 0
        assertEq(strategy.tokenId(), 0);

        vm.startPrank(LIQUIDITY_HOLDER);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5000 USDC + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        (uint liquidity, uint amount0, uint amount1) = strategy.deposit(5000_000000, 2 ether, 0, 0, block.timestamp);

        vm.stopPrank();

        // Confirm the tokenId that has been minted and that our strategy contract is the owner
        assertEq(strategy.tokenId(), 483377);
        assertEq(ERC721(UNISWAP_POSITION_MANAGER).ownerOf(483377), address(strategy));

        // Confirm our callback results
        assertEq(liquidity, 86433059121040);
        assertEq(amount0, 3735336855);
        assertEq(amount1, 1999999999999976962);

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 0);

        // We can now withdraw from the strategy
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdraw.selector, treasury, 0, 0, block.timestamp, uint128(liquidity / 4)));

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 933834213);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 499999999999994240);

        // We can also make a subsequent withdrawal
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdraw.selector, treasury, 0, 0, block.timestamp, uint128(liquidity / 2)));

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 2801502640);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 1499999999999982720);

        // Our withdrawals should not have yetgenerated any rewards
        (address[] memory totalRewardTokens, uint[] memory totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], TOKEN_A);
        assertEq(totalRewardTokens[1], TOKEN_B);
        assertEq(totalRewardAmounts[0], 0);
        assertEq(totalRewardAmounts[1], 0);

        // Mock some rewards against our pool. When we call collect it will be the UV3 pool that
        // sends the tokens, not the position manager. So we give the tokens to the pool, but update
        // the position on our {PositionManager}.
        deal(TOKEN_A, 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640, 10000_000000);  // $10,000
        deal(TOKEN_B, 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640, 5 ether);    // 5 WETH

        // Update our returned positions to modify the tokens owed to our strategy. We don't reference
        // any of the other variables, so we can just give them nulled values for now.
        vm.mockCall(
            address(UNISWAP_POSITION_MANAGER),
            abi.encodeWithSelector(IUniswapV3NonfungiblePositionManager.positions.selector),
            abi.encode(
                uint96(0),
                address(0),
                TOKEN_A,
                TOKEN_B,
                POOL_FEE,
                int24(-887270),
                int24(887270),
                uint128(21608264780260),
                10000_000000,
                5 ether,
                uint128(10000_000000),
                uint128(5 ether)
            )
        );

        // We should now see some rewards available in the pool
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], TOKEN_A);
        assertEq(totalRewardTokens[1], TOKEN_B);
        assertEq(totalRewardAmounts[0], 10000_000000);
        assertEq(totalRewardAmounts[1], 5 ether);

        (address[] memory snapshotTokens, uint[] memory snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], TOKEN_A);
        assertEq(snapshotTokens[1], TOKEN_B);
        assertEq(snapshotAmounts[0], 10000_000000);
        assertEq(snapshotAmounts[1], 5 ether);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotTokens, snapshotAmounts) = strategy.snapshot();
        assertEq(snapshotTokens[0], TOKEN_A);
        assertEq(snapshotTokens[1], TOKEN_B);
        assertEq(snapshotAmounts[0], 0);
        assertEq(snapshotAmounts[1], 0);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], TOKEN_A);
        assertEq(totalRewardTokens[1], TOKEN_B);
        assertEq(totalRewardAmounts[0], 10000_000000);
        assertEq(totalRewardAmounts[1], 5 ether);
    }

    /**
     * If our strategy tries to deposit no tokens, then we revert early.
     */
    function test_CannotDepositZeroValue() public {
        // Confirm our test user's starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(LIQUIDITY_HOLDER), 100000_000000);
        assertEq(IERC20(TOKEN_B).balanceOf(LIQUIDITY_HOLDER), 100_000000000000000000);

        // Confirm our strategies starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 0);

        vm.startPrank(LIQUIDITY_HOLDER);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Cannot deposit with 0 of either token
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit(0, 0, 0, 0, block.timestamp);

        vm.stopPrank();

        // Confirm our strategy has no balance at closing
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 0);

        // As we were unable to successfully deposit, will still won't have any token minted
        assertEq(strategy.tokenId(), 0);
    }

    /**
     * Ensure that we can withdraw a specific percentage value form the strategy.
     */
    function test_CanWithdrawPercentage() public {
        vm.startPrank(LIQUIDITY_HOLDER);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5000 USDC + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        strategy.deposit(5000_000000, 2 ether, 0, 0, block.timestamp);

        vm.stopPrank();

        // Action a 20% percentage withdrawal through the strategy factory
        strategyFactory.withdrawPercentage(address(strategy), 2000);

        // Confirm that our recipient received the expected amount of tokens
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 3);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 4);

        // Confirm that the strategy still holds the expected number of yield token
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 5);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 6);
    }

}
