// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapV3PricingExecutor, UnknownUniswapPool} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';

import {FloorTest} from '../utilities/Environments.sol';

/**
 * For this test we will want to implement Forge forking cheatcode to ensure
 * our tests run at a specific block number. This will ensure that we can
 * assert our response values without variance.
 *
 * https://book.getfoundry.sh/forge/fork-testing#forking-cheatcodes
 */
contract UniswapV3PricingExecutorTest is FloorTest {
    UniswapV3PricingExecutor executor;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_075_930;

    address internal UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    address internal FLOORV1 = 0xf59257E961883636290411c11ec5Ae622d19455e; // 9 decimals
    address internal UNKNOWN = 0x0000000000000000000000000000000000000064;
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // 6 decimals
    address internal X2Y2 = 0x1E4EDE388cbc9F4b5c79681B7f94d36a11ABEBC9; // 18 decimals

    uint128 internal FLOORV1_ETH_PRICE = 1550575122257810; // 001550575122257810
    uint128 internal USDC_ETH_PRICE = 819268955245994; // 000819268955245994
    uint128 internal X2Y2_ETH_PRICE = 34621444139728; // 000034621444139728

    uint128 internal USDC_FLOOR_PRICE = 528364568401592303; // 0.528364568401592303
    uint128 internal X2Y2_FLOOR_PRICE = 22328130796601020; // 0.022328130796601020

    constructor() forkBlock(BLOCK_NUMBER) {}

    /**
     * Deploy our contract, set up our fork and roll the block to set up our fork.
     *
     * A number of our tests require prices to already be set in our structure. For
     * this, we will need to call `updatePrice` against a small number of test tokens.
     *
     * The `updatePrice` logic will be tested in proper scrutiny in separate tests.
     */
    function setUp() public {
        // Set up our pricing executor
        executor = new UniswapV3PricingExecutor(UNISWAP_FACTORY, FLOORV1);
    }

    /**
     * Our name function is just a simple helper to get a name reference for the
     * executor.
     */
    function test_Name() public {
        assertEq(executor.name(), 'UniswapV3PricingExecutor');
    }

    /**
     * We need to check that we can get the stored ETH price of a token. This will be
     * the value that is returned from our `updatePrice` call and stored in the contract.
     */
    function test_ETHPriceOfToken() public {
        assertEq(executor.getETHPrice(USDC), USDC_ETH_PRICE);
    }

    /**
     * If we attempt to query an unknown token that we don't have an internal mapping
     * for, then we will expect a revert.
     */
    function test_ETHPriceOfUnknownToken() public {
        vm.expectRevert(UnknownUniswapPool.selector);
        executor.getETHPrice(UNKNOWN);
    }

    /**
     * The output of FLOOR should be the same as checking against any other token, but
     * just for the sake of completionism I've included it as it's own test.
     */
    function test_ETHPriceOfFloor() public {
        assertEq(executor.getETHPrice(FLOORV1), FLOORV1_ETH_PRICE);
    }

    /**
     * Rather than just providing a single token, we need to also be able to provide
     * an array of tokens to test against for when we want to get multiple prices in
     * a single transaction. The response in this instance will be an array of prices
     * in the same order as the addresses passed in.
     */
    function test_ETHPriceOfMultipleTokens() public {
        address[] memory tokens = new address[](3);
        tokens[0] = X2Y2;
        tokens[1] = FLOORV1;
        tokens[2] = USDC;

        uint[] memory prices = executor.getETHPrices(tokens);

        assertEq(prices[0], X2Y2_ETH_PRICE);
        assertEq(prices[1], FLOORV1_ETH_PRICE);
        assertEq(prices[2], USDC_ETH_PRICE);
    }

    /**
     * Get a gas estimate of 25 tokens.
     */
    function test_ETHPriceOfManyTokens() public {
        address[] memory tokens = new address[](25);
        for (uint i; i < 25;) {
            tokens[i] = USDC;
            unchecked {
                ++i;
            }
        }

        executor.getETHPrices(tokens);
    }

    /**
     * If we action a call with no tokens provided, then we expect a revert.
     */
    function test_ETHPriceOfMultipleTokensWithNoTokens() public {
        address[] memory tokens = new address[](0);
        uint[] memory prices = executor.getETHPrices(tokens);
        assertEq(prices.length, 0);
    }

    /**
     * If just a single token is passed in, then this will just return the single
     * price, but in an array.
     */
    function test_ETHPriceOfMultipleTokensWithSingleTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = FLOORV1;

        uint[] memory prices = executor.getETHPrices(tokens);

        assertEq(prices[0], FLOORV1_ETH_PRICE);
    }

    /**
     * If we have multiple tokens passed in, but there are some invalid tokens in
     * the mix, then we expect it to be reverted as we don't want to return a
     * token = 0 mapping.
     */
    function test_ETHPriceOfMultipleTokensWithPartiallyInvalidTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = UNKNOWN;

        vm.expectRevert(UnknownUniswapPool.selector);
        executor.getETHPrices(tokens);
    }

    /**
     * Once we have an ETH price for both FLOOR and a token, then we can calculate
     * the FLOOR value of a token.
     */
    function test_FloorPriceOfToken() public {
        assertEq(executor.getFloorPrice(USDC), USDC_FLOOR_PRICE);
    }

    /**
     * If we don't have a price for a token, then we expect a revert.
     */
    function test_FloorPriceOfUnknownToken() public {
        vm.expectRevert(UnknownUniswapPool.selector);
        executor.getFloorPrice(UNKNOWN);
    }

    /**
     * We can pass multiple tokens as input in an array and we expect to get an
     * array of FLOOR prices returned, maintaining the same order as the input.
     */
    function test_FloorPriceOfMultipleTokens() public {
        address[] memory tokens = new address[](2);
        tokens[0] = X2Y2;
        tokens[1] = USDC;

        uint[] memory prices = executor.getFloorPrices(tokens);

        assertEq(prices[0], X2Y2_FLOOR_PRICE);
        assertEq(prices[1], USDC_FLOOR_PRICE);
    }

    /**
     * Get a gas estimate of 25 tokens.
     */
    function test_FloorPriceOfManyTokens() public {
        address[] memory tokens = new address[](25);
        for (uint i; i < 25;) {
            tokens[i] = USDC;
            unchecked {
                ++i;
            }
        }

        executor.getFloorPrices(tokens);
    }

    /**
     * If we are not sent any tokens, then we expect a revert.
     */
    function test_FloorPriceOfMultipleTokensWithNoTokens() public {
        address[] memory tokens = new address[](0);
        uint[] memory prices = executor.getFloorPrices(tokens);
        assertEq(prices.length, 0);
    }

    /**
     * If just a single token is passed in, then this will just return the single
     * price, but in an array.
     */
    function test_FloorPriceOfMultipleTokensWithSingleTokens() public {
        address[] memory tokens = new address[](1);
        tokens[0] = X2Y2;

        uint[] memory prices = executor.getFloorPrices(tokens);

        assertEq(prices[0], X2Y2_FLOOR_PRICE);
    }

    /**
     * We should be able to query the liquidity of a pool.
     */
    function test_CanGetTheLiquidityOfAPool() public {
        assertEq(executor.getLiquidity(X2Y2), 5_229401882323523784);
    }
}
