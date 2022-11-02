// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

/**
 * For this test we will want to implement Forge forking cheatcode to ensure
 * our tests run at a specific block number. This will ensure that we can
 * assert our response values without variance.
 *
 * https://book.getfoundry.sh/forge/fork-testing#forking-cheatcodes
 */
contract UniswapV3PricingExecutorTest is Test {

    /**
     * Deploy our contract, set up our fork and roll the block to set up our fork.
     *
     * A number of our tests require prices to already be set in our structure. For
     * this, we will need to call `updatePrice` against a small number of test tokens.
     *
     * The `updatePrice` logic will be tested in proper scrutiny in separate tests.
     */
    function setUp() public {}

    /**
     * Our name function is just a simple helper to get a name reference for the
     * executor. This is set
     */
    function testName() public {}

    /**
     * All of our pricing executors need to provide the correct interface support,
     * so this test just ensures that the `bytes4` interface identifier is correctly
     * determined.
     */
    function testInterfaceSupport() public {}

    /**
     * We need to check that we can get the stored ETH price of a token. This will be
     * the value that is returned from our `updatePrice` call and stored in the contract.
     */
    function testETHPriceOfToken() public {}

    /**
     * If we attempt to query an unknown token that we don't have an internal mapping
     * for, then we will expect a revert.
     */
    function testETHPriceOfUnknownToken() public {}

    /**
     * The output of FLOOR should be the same as checking against any other token, but
     * just for the sake of completionism I've included it as it's own test.
     */
    function testETHPriceOfFloor() public {}

    /**
     * Rather than just providing a single token, we need to also be able to provide
     * an array of tokens to test against for when we want to get multiple prices in
     * a single transaction. The response in this instance will be an array of prices
     * in the same order as the addresses passed in.
     */
    function testETHPriceOfMultipleTokens() public {}

    /**
     * If we action a call with no tokens provided, then we expect a revert.
     */
    function testETHPriceOfMultipleTokensWithNoTokens() public {}

    /**
     * If just a single token is passed in, then this will just return the single
     * price, but in an array.
     */
    function testETHPriceOfMultipleTokensWithSingleTokens() public {}

    /**
     * If we have multiple tokens passed in, but there are some invalid tokens in
     * the mix, then we expect it to be reverted as we don't want to return a
     * token = 0 mapping.
     */
    function testETHPriceOfMultipleTokensWithPartiallyInvalidTokens() public {}

    /**
     * Once we have an ETH price for both FLOOR and a token, then we can calculate
     * the FLOOR value of a token.
     */
    function testFloorPriceOfToken() public {}

    /**
     * If we don't have a price for a token, then we expect a revert.
     */
    function testFloorPriceOfUnknownToken() public {}

    /**
     * 1 FLOOR = 1 FLOOR.
     */
    function testFloorPriceOfFloor() public {}

    /**
     * We can pass multiple tokens as input in an array and we expect to get an
     * array of FLOOR prices returned, maintaining the same order as the input.
     */
    function testFloorPriceOfMultipleTokens() public {}

    /**
     * If we are not sent any tokens, then we expect a revert.
     */
    function testFloorPriceOfMultipleTokensWithNoTokens() public {}

    /**
     * If just a single token is passed in, then this will just return the single
     * price, but in an array.
     */
    function testFloorPriceOfMultipleTokensWithSingleTokens() public {}

    /**
     * When we update a price, we keep an internal reference for when the token
     * price was last updated. This test will check the value of the timestamp
     * both before and after we call `updatePrice`.
     */
    function testPriceFreshnessAfterPriceUpdate() public {}

    /**
     * If we try to test the freshness of an unknown token, we will expect a
     * revert as we will detect a value of `0`.
     */
    function testPriceFreshnessOfUnknownToken() public {}

    /**
     * To test gas usage, we want to check the average gas usage when finding the
     * price for TOKEN -> ETH.
     */
    function testUpdatePriceWithSingleHop() public {}

    /**
     * To test gas usage and see if there can be any savings made, we want to
     * check the average gas usage when finding the price for TOKEN -> ETH ->
     * FLOOR.
     *
     * If this is less gas intensive, then it would mean that we would not
     * have an ETH price reference for any token, but instead just internally
     * store all prices as their FLOOR equivalent.
     */
    function testUpdatePriceWithDoubleHop() public {}

    /**
     * We need to ensure that we can send a single token to be checked for it's
     * current price. We will need to ensure that the correct price are returned
     * and that the {TokenPriceUpdated} event is emitted as expected.
     */
    function testUpdatePrice() public {}

    /**
     * If we are sent no tokens to an `updatePrice` call then we expect a revert.
     */
    function testUpdatePriceWithNoTokens() public {}

    /**
     * We need to ensure that we can send multiple token to be checked for their
     * current prices. We will need to ensure that the correct prices are returned
     * and that the {TokenPriceUpdated} events are emitted as expected.
     */
    function testUpdatePriceWithMultipleTokens() public {}

    /**
     * If an invalid token is sent to our `updatePrice` call, then we expect the
     * process to still run, but {TokenPriceUpdated} will not be emitted for any
     * invalid tokens.
     */
    function testUpdatePriceWithInvalidToken() public {}

}
