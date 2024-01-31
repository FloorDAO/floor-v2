// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ERC20Mock} from './../mocks/erc/ERC20Mock.sol';
import {UniswapV3StrategyMock} from './../mocks/UniswapV3StrategyMock.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';
import {CannotDepositZeroAmount} from '@floor/utils/Errors.sol';
import {Treasury} from '@floor/Treasury.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

import {FloorTest} from '../utilities/Environments.sol';


/**
 * @dev This is defined as {Test} rather than {FloorTest} as there was a Foundry
 * bug with the block fork that was causing the contracts to read incorrectly.
 */
contract UniswapV3StrategyTest is FloorTest {
    /// The mainnet contract address of our Uniswap Position Manager
    address internal constant UNISWAP_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    uint24 internal constant POOL_FEE = 500;

    /// Two tokens that we can test with
    address internal constant TOKEN_A = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC (6 decimals)
    address internal constant TOKEN_B = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH (18 decimals)
    address internal TOKEN_C;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_989_012;

    /// Store our internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;
    UniswapV3Strategy strategy;

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
        strategyImplementation = address(new UniswapV3Strategy());

        // Create our {CollectionRegistry} and approve our collections
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        collectionRegistry.approveCollection(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
        collectionRegistry.approveCollection(0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313);

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
        treasury = address(new Treasury(
            address(authorityRegistry),
            address(1),
            TOKEN_B  // WETH
        ));
        strategyFactory.setTreasury(treasury);

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('USDC/WETH UV3 Pool'),
            strategyImplementation,
            abi.encode(
                TOKEN_A, // address token0
                TOKEN_B, // address token1
                POOL_FEE, // uint24 fee
                0, // uint96 sqrtPriceX96
                -887270, // int24 tickLower
                887270, // int24 tickUpper
                address(0), // address pool
                UNISWAP_POSITION_MANAGER // address positionManager
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = UniswapV3Strategy(_strategy);
        strategyId = _strategyId;

        // Deal some additional USDC and WETH tokens
        deal(TOKEN_A, address(this), 100_000_000000);
        deal(TOKEN_B, address(this), 100_000000000000000000);
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
        assertEq(IERC20(TOKEN_A).balanceOf(address(this)), 100000_000000);
        assertEq(IERC20(TOKEN_B).balanceOf(address(this)), 100_000000000000000000);

        // Confirm our strategies starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 0);

        // Before our first deposit, our tokenId should be 0
        assertEq(strategy.tokenId(), 0);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5000 USDC + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        (uint liquidity, uint amount0, uint amount1) = strategy.deposit(5000_000000, 2 ether, 0, 0, block.timestamp);

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
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 4))
        );

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 933834213);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 499999999999994240);

        // We can also make a subsequent withdrawal
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 2))
        );

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 2801502640);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 1499999999999982720);

        // Our withdrawals should not have yetgenerated any rewards
        (address[] memory totalRewardTokens, uint[] memory totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], TOKEN_A);
        assertEq(totalRewardTokens[1], TOKEN_B);
        assertEq(totalRewardAmounts[0], 0);
        assertEq(totalRewardAmounts[1], 0);

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
        (address[] memory availableTokens, uint[] memory availableAmounts) = strategy.available();
        assertEq(availableTokens[0], TOKEN_A);
        assertEq(availableTokens[1], TOKEN_B);
        assertEq(availableAmounts[0], 10108_693603);
        assertEq(availableAmounts[1], 5_056281262_254956426);

        // We should now see some rewards available in the pool
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], TOKEN_A);
        assertEq(totalRewardTokens[1], TOKEN_B);
        assertEq(totalRewardAmounts[0], availableAmounts[0]);
        assertEq(totalRewardAmounts[1], availableAmounts[1]);

        (address[] memory snapshotStrategies, uint[] memory snapshotAmounts,) = strategyFactory.snapshot(0);
        assertEq(snapshotStrategies[0], address(strategy));
        assertEq(snapshotAmounts[0], availableAmounts[1]);

        // If we call the snapshot function against, we should see that no tokens are detected
        (snapshotStrategies, snapshotAmounts,) = strategyFactory.snapshot(0);
        assertEq(snapshotStrategies[0], address(strategy));
        assertEq(snapshotAmounts[0], 0);

        // We can, however, still see the total amounts of rewards generated
        (totalRewardTokens, totalRewardAmounts) = strategy.totalRewards();
        assertEq(totalRewardTokens[0], TOKEN_A);
        assertEq(totalRewardTokens[1], TOKEN_B);
        assertEq(totalRewardAmounts[0], availableAmounts[0]);
        assertEq(totalRewardAmounts[1], availableAmounts[1]);
    }

    /**
     * If our strategy tries to deposit no tokens, then we revert early.
     */
    function test_CannotDepositZeroValue() public {
        // Confirm our test user's starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(address(this)), 100000_000000);
        assertEq(IERC20(TOKEN_B).balanceOf(address(this)), 100_000000000000000000);

        // Confirm our strategies starting balance
        assertEq(IERC20(TOKEN_A).balanceOf(address(strategy)), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(address(strategy)), 0);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Cannot deposit with 0 of either token
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit(0, 0, 0, 0, block.timestamp);

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
        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5000 USDC + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        strategy.deposit(10000_000000, 100 ether, 0, 0, block.timestamp);

        // Action a 20% percentage withdrawal through the strategy factory
        strategyFactory.withdrawPercentage(address(strategy), 2000);

        // Confirm that our recipient received the expected amount of tokens
        assertEq(IERC20(TOKEN_A).balanceOf(address(this)), 91999999999);
        assertEq(IERC20(TOKEN_B).balanceOf(address(this)), 95716584441191985162);
    }

    function test_CanGetPoolTokenBalances() public {
        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5000 USDC + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        (uint liquidity, uint amount0, uint amount1) = strategy.deposit(5000_000000, 2 ether, 0, 0, block.timestamp);

        assertEq(amount0, 3735336855);
        assertEq(amount1, 1999999999999976962);
        assertEq(liquidity, 86433059121040);

        // Get our token balances and we will see a dust level difference
        (uint token0Amount, uint token1Amount, uint128 liquidityAmount) = strategy.tokenBalances();
        assertEq(token0Amount, 3735336854);
        assertEq(token1Amount, 1999999999999976961);
        assertEq(liquidityAmount, 86433059121040);

        // Make another deposit
        (liquidity, amount0, amount1) = strategy.deposit(2500_000000, 1 ether, 0, 0, block.timestamp);

        // These values will appear to be 50% of the current holdings, as the relative
        // values are now 50% of the total supply, rather than in the previous deposit
        // it accounted for 100%.
        assertEq(amount0, 1867668428);
        assertEq(amount1, 999999999999988481);
        assertEq(liquidity, 43216529560520);

        // Our `tokenBalances` call will now show our total holdings
        (token0Amount, token1Amount, liquidityAmount) = strategy.tokenBalances();
        assertEq(token0Amount, 5603005281);
        assertEq(token1Amount, 2999999999999965442);
        assertEq(liquidityAmount, 129649588681560);
    }

    /**
     * This test ensures that we can create a new pool, as the pool set up in this test
     * hits on an existing USDC/WETH pool. There may be some differences in logic and calls
     * if the pool is new.
     */
    function test_CanCreateNewPool() external {
        // Create our ERC20Mock and mint a bunch of tokens to play with
        ERC20Mock mock = new ERC20Mock();
        mock.setDecimals(18);

        // Register our token pseudo-constant
        TOKEN_C = address(mock);

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('MOCK/WETH UV3 Pool'),
            strategyImplementation,
            abi.encode(
                TOKEN_C, // address token0
                TOKEN_B, // address token1
                POOL_FEE, // uint24 fee
                92527072418752397425999, // uint96 sqrtPriceX96
                -887270, // int24 tickLower
                887270, // int24 tickUpper
                address(0), // address pool
                UNISWAP_POSITION_MANAGER // address positionManager
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = UniswapV3Strategy(_strategy);
        strategyId = _strategyId;

        // Deal some additional Mock and WETH tokens
        deal(TOKEN_C, address(this), 100 ether);
        deal(TOKEN_B, address(this), 100 ether);

        // Before our first deposit, our tokenId should be 0
        assertEq(strategy.tokenId(), 0);

        // Set our max approvals
        IERC20(TOKEN_C).approve(address(strategy), 100 ether);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5 MOCK + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        (uint liquidity, uint amount0, uint amount1) = strategy.deposit(100 ether, 100 ether, 0, 0, block.timestamp);

        // Confirm the tokenId that has been minted and that our strategy contract is the owner
        assertEq(strategy.tokenId(), 483377);
        assertEq(ERC721(UNISWAP_POSITION_MANAGER).ownerOf(483377), address(strategy));

        // Confirm our callback results
        assertEq(liquidity, 116785584169131);
        assertEq(amount0, 99999999999999649917);
        assertEq(amount1, 136388727);

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_C).balanceOf(treasury), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 0);

        // We can now withdraw from the strategy
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 4))
        );

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_C).balanceOf(treasury), 24999999999999270276);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 34097181);
    }

    function test_CanRegiterAgainstExistingPool() external {
        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('USDC/WETH UV3 Pool'),
            strategyImplementation,
            abi.encode(
                TOKEN_A, // address token0
                TOKEN_B, // address token1
                POOL_FEE, // uint24 fee
                0, // uint96 sqrtPriceX96
                -887270, // int24 tickLower
                887270, // int24 tickUpper
                0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640, // address pool
                UNISWAP_POSITION_MANAGER // address positionManager
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = UniswapV3Strategy(_strategy);
        strategyId = _strategyId;

        // Deal some additional USDC and WETH tokens
        deal(TOKEN_A, address(this), 100_000_000000);
        deal(TOKEN_B, address(this), 100_000000000000000000);

        // Before our first deposit, our tokenId should be 0
        assertEq(strategy.tokenId(), 0);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), 100000_000000);
        IERC20(TOKEN_B).approve(address(strategy), 100 ether);

        // Make our initial deposit that will mint our token (5000 USDC + 2 WETH). As this is
        // our first deposit, we will also mint a token.
        (uint liquidity, uint amount0, uint amount1) = strategy.deposit(5000_000000, 2 ether, 0, 0, block.timestamp);

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
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 4))
        );
    }

    /**
     * If a deposit has not been made against the strategy, then making other
     * function calls that depend on a token may raise an exception if they
     * hit Uniswap. For this reason, we need to ensure that our functions don't
     * raise exceptions if they are called before that deposit is made and the
     * pool token is minted.
     */
    function test_CanCallFunctionsWithoutTokenId() public {
        // Strategy
        (address[] memory tokens_, uint[] memory amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A);
        assertEq(tokens_[1], TOKEN_B);
        assertEq(amounts_[0], 0);
        assertEq(amounts_[1], 0);

        (uint token0Amount, uint token1Amount, uint128 liquidity) = strategy.tokenBalances();
        assertEq(token0Amount, 0);
        assertEq(token1Amount, 0);
        assertEq(liquidity, 0);

        (tokens_) = strategy.validTokens();
        assertEq(tokens_[0], TOKEN_A);
        assertEq(tokens_[1], TOKEN_B);

        (tokens_, amounts_) = strategy.totalRewards();
        assertEq(tokens_[0], TOKEN_A);
        assertEq(tokens_[1], TOKEN_B);
        assertEq(amounts_[0], 0);
        assertEq(amounts_[1], 0);

        // Strategy Factory
        (address[] memory snapshotStrategies, uint[] memory snapshotAmounts,) = strategyFactory.snapshot(0);
        assertEq(snapshotStrategies[0], address(strategy));
        assertEq(snapshotAmounts[0], 0);

        // No return value, just need to ensure that it can run
        strategyFactory.harvest(strategyId);

        // No return value, just need to ensure that it can run
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, 0)
        );

        (tokens_, amounts_) = strategyFactory.withdrawPercentage(address(strategy), 50_00);
        assertEq(tokens_[0], TOKEN_A);
        assertEq(tokens_[1], TOKEN_B);
        assertEq(amounts_[0], 0);
        assertEq(amounts_[1], 0);
    }

}


/**
 * An additional test suite that takes a specific block reference against a Sepolia scenario.
 */
contract UniswapV3StrategyTestTwo is FloorTest {
    /// The mainnet contract address of our Uniswap Position Manager
    address internal constant UNISWAP_POSITION_MANAGER = 0x1238536071E1c677A632429e3655c799b22cDA52;
    uint24 internal constant POOL_FEE = 10000;

    /// Two tokens that we can test with
    address internal constant TOKEN_A = 0xfEff35011D41F1d60655a008405D3FA851C29822; // FLOOR (18 decimals)
    address internal constant TOKEN_B = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // WETH (18 decimals)

    /// Our Uniswap V3 test pool address
    address internal constant POOL_ADDRESS = 0xc09D4849a695799FC5fD0022b0A740614c404063;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 5_184_087;

    /**
     * Check that we can get the correct amount of available tokens.
     */
    function test_CanGetAvailableTokens() public {
        // Generate a sepolia fork
        uint sepoliaFork = vm.createFork(vm.rpcUrl('sepolia'));

        // Select our fork for the VM
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(BLOCK_NUMBER);

        // Confirm that our block number has set successfully
        require(block.number == BLOCK_NUMBER);

        // Query the strategy with overwritten values to etch in the params
        UniswapV3StrategyMock strategy = new UniswapV3StrategyMock();
        strategy.initialize(
            bytes32('USDC/WETH UV3 Pool'),
            0,
            abi.encode(
                TOKEN_A, // address token0
                TOKEN_B, // address token1
                POOL_FEE, // uint24 fee
                2480730815269278797686718984, // uint96 sqrtPriceX96
                -887200, // int24 tickLower
                887200, // int24 tickUpper
                POOL_ADDRESS, // address pool
                UNISWAP_POSITION_MANAGER // address positionManager
            )
        );

        // Set our tokenId
        strategy.setTokenId(uint24(7801));

        // Call available
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        // We should see 0.1 FLOOR token and 0 WETH available to claim
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
        assertEq(amounts[0], 100000000_099999999);
        assertEq(amounts[1], 0);
    }

    function test_CanGetAvailableTokensAlt() public {
        // Generate a sepolia fork
        uint sepoliaFork = vm.createFork(vm.rpcUrl('sepolia'));

        // Select our fork for the VM
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(5187182);

        // Confirm that our block number has set successfully
        require(block.number == 5187182);

        // Query the strategy with overwritten values to etch in the params
        UniswapV3StrategyMock strategy = new UniswapV3StrategyMock();
        strategy.initialize(
            bytes32('USDC/WETH UV3 Pool'),
            0,
            abi.encode(
                0xfEff35011D41F1d60655a008405D3FA851C29822, // address token0
                0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, // address token1
                10000, // uint24 fee
                2480730815269278797686718984, // uint96 sqrtPriceX96
                -887200, // int24 tickLower
                887200, // int24 tickUpper
                0xc09D4849a695799FC5fD0022b0A740614c404063, // address pool
                UNISWAP_POSITION_MANAGER // address positionManager
            )
        );

        // Set our tokenId
        strategy.setTokenId(uint24(7813));

        // Call available
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        // We should see 0.1 FLOOR token and 0 WETH available to claim
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
        assertEq(amounts[0], 66447390278528247);
        assertEq(amounts[1], 7309212930638107);
    }

}
