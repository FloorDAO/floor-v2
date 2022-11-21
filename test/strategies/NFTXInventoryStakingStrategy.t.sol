// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract NFTXInventoryStakingStrategyTest is Test {

    /**
     * Our yield token should be the xToken that is defined by the
     * NFTX InventoryStaking contract.
     */
    function testCanGetYieldToken() public {}

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
    function testCanGetUnderlyingToken() public {}

    /**
     * This should return an xToken that is stored in the strategy.
     */
    function testCanDepositToInventoryStaking() public {}

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function testCannotDepositInvalidTokenToInventoryStaking() public {}

    /**
     * We need to be able to claim all pending rewards from the NFTX
     * {InventoryStaking} contract. These should be put in the strategy
     * contract.
     */
    function testCanClaimRewards() public {}

    /**
     * Even when we have no rewards to claim, we should still be able
     * to make the request but we just expect a 0 value to be returned.
     */
    function testCanClaimRewardsWhenEmpty() public {}

    /**
     * We should be able to partially exit our position, having just
     * some of our vault ERC20 tokens returned and the xToken burnt
     * from the strategy.
     */
    function testCanPartiallyExitPosition() public {}

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
     */
    function testCannotExitBeyondPosition() public {}

    /**
     * If we don't have a stake in the {InventoryStaking} contract and
     * we try to exit our (non-existant) position then we should expect
     * a revert.
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
    function testCanDetermineRewardsAvailableWhenZero() public {}

    /**
     * When we have generated yield we want to be sure that our helper
     * function returns the correct value.
     */
    function testCanCalculateTotalRewardsGenerated() public {}

}
