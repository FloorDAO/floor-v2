// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapV3PricingExecutor, UnknownUniswapPool} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';

import {ERC20Mock} from '../mocks/erc/ERC20Mock.sol';
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
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint128 internal FLOORV1_ETH_PRICE = 1566237497230112;
    uint128 internal USDC_ETH_PRICE = 827544399238378;
    uint128 internal X2Y2_ETH_PRICE = 34971155696695;

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
        executor = new UniswapV3PricingExecutor(UNISWAP_FACTORY, WETH);
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
        address mockToken = address(new ERC20Mock());

        vm.expectRevert(UnknownUniswapPool.selector);
        executor.getETHPrice(mockToken);
    }

    /**
     * The output of FLOOR should be the same as checking against any other token, but
     * just for the sake of completionism I've included it as it's own test.
     */
    function test_ETHPriceOfFloor() public {
        assertEq(executor.getETHPrice(FLOORV1), FLOORV1_ETH_PRICE);
    }

    /**
     * If a token is tested with an invalid number of decimals then we expect it
     * to revert.
     */
    function test_ETHPriceOfTokenWithInvalidDecimals(uint8 decimals) public {
        // Ensure that we only test mocked tokens with > 18 decimals
        vm.assume(decimals > 18);

        // Set our a mocked token with invalid decimals
        ERC20Mock mock = new ERC20Mock();
        mock.setDecimals(decimals);

        vm.expectRevert('Invalid token decimals');
        executor.getETHPrice(address(mock));
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
     * If we action a call with no tokens provided, then we should just expect to
     * receive an empty array.
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
        address[] memory tokens = new address[](3);
        tokens[0] = X2Y2;
        tokens[1] = address(new ERC20Mock());
        tokens[2] = USDC;

        vm.expectRevert(UnknownUniswapPool.selector);
        executor.getETHPrices(tokens);
    }

}
