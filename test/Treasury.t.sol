// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract TreasuryTest is Test {

    /**
     * Checks that an authorised user can an arbritrary amount of floor.
     *
     * This should emit {FloorMinted}.
     */
    function testCanMintFloor(uint amount) public {}

    /**
     * Ensure that only the {TreasuryManager} can action the minting of floor.
     *
     * This should not emit {FloorMinted}.
     */
    function testCannotMintFloorWithoutPermissions() public {}

    /**
     * We should validate the amount passed into the floor minting to ensure that
     * a zero value cannot be requested.
     *
     * This should not emit {FloorMinted}.
     */
    function testCannotMintZeroFloor() public {}

    /**
     * We should be able to mint the floor token equivalent of a token, based on
     * the internally stored conversion value.
     *
     * This should emit {FloorMinted}.
     */
    function testCanMintTokenFloor(uint amount) public {}

    /**
     * We should be able to mint floor against an unbacked token, as the token
     * can be held in an external platform as unclaimed reward yield.
     *
     * This should emit {FloorMinted}.
     */
    function testCanMintUnbackedTokenFloor() public {}

    /**
     * We want to internally validate to ensure that we don't attempt to mint
     * the floor equivalent of 0 tokens. This expects a revert.
     *
     * This should not emit {FloorMinted}.
     */
    function testCannotMintZeroTokenFloor() public {}

    /**
     * If we don't have an internally stored conversion price for token <=> floor
     * then we won't be able to mint floor against the token. This expects a
     * revert.
     *
     * This should not emit {FloorMinted}.
     */
    function testCannotMintTokenFloorWithoutPrice() public {}

    /**
     * Our contract should be able to receive the native token of the chain.
     *
     * This should emit {Deposit}.
     */
    function testCanDepositNativeToken() public {}

    /**
     * We should be able to deposit any ERC20 token with varied amounts into
     * the {Treasury}.
     *
     * This should emit {DepositERC20}.
     */
    function testCanDepositERC20() public {}

    /**
     * We should be able to deposit any ERC721 token with varied amounts into
     * the {Treasury}.
     *
     * This should emit {DepositERC721}.
     */
    function testCanDepositERC721() public {}

    /**
     * Our contract should be able to withdraw the native token of the chain.
     *
     * This should emit {Withdraw}.
     */
    function testCanWithdrawNativeToken() public {}

    /**
     * Our withdraw function only wants to be available to a specific user role
     * to ensure that not anyone can just rob us.
     *
     * This should not emit {Withdraw}.
     */
    function testCannotWithdrawNativeTokenWithoutPermissions() public {}

    /**
     * We should be able to withdraw any ERC20 token with varied amounts from
     * the {Treasury}.
     *
     * This should emit {WithdrawERC20}.
     */
    function testCanWithdrawERC20() public {}

    /**
     * If we don't have the ERC20 token, or hold insufficient tokens, then we
     * expect a revert.
     *
     * This should not emit {WithdrawERC20}.
     */
    function testCannotWithdrawInvalidERC20() public {}

    /**
     * If we don't have the right user role then we should not be able to transfer
     * the token and we expect a revert.
     *
     * This should not emit {WithdrawERC20}.
     */
    function testCannotWithdrawERC20WithoutPermissions() public {}

    /**
     * We should be able to withdraw any ERC721 token with varied amounts from
     * the {Treasury}.
     *
     * This should emit {WithdrawERC721}.
     */
    function testCanWithdrawERC721() public {}

    /**
     * If we don't have the ERC721 token, or hold insufficient tokens, then we
     * expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function testCannotWithdrawInvalidERC721() public {}

    /**
     * If we don't have the right user role then we should not be able to transfer
     * the token and we expect a revert.
     *
     * This should not emit {WithdrawERC721}.
     */
    function testCannotWithdrawERC721WithoutPermissions() public {}

    /**
     * We want to ensure that we can update the address of the {RewardsLedger}
     * contract.
     */
    function testCanSetRewardsLedgerContract() public {}

    /**
     * We will need to validate the {RewardsLedger} address to ensure that we
     * don't pass a `NULL` address value. We expect a revert.
     */
    function testCannotSetRewardsLedgerContractNullValue() public {}

    /**
     * Only a `TreasuryManager` should be able to update our {RewardsLedger}
     * address. If another user role calls this function then we expect it to
     * be reverted.
     */
    function testCannotSetRewardsLedgerContractWithoutPermissions() public {}

    /**
     * Gauge Weight Vote get/set.
     */
    function testCanSetGaugeWeightVoteContract() public {}
    function testCannotSetGaugeWeightVoteContractNullValue() public {}
    function testCannotSetGaugeWeightVoteContractWithoutPermissions() public {}

    /**
     * Retained Treasury Yield Percentage get/set.
     */
    function testCanSetRetainedTreasuryYieldPercentage() public {}
    function testCannotSetRetainedTreasuryYieldPercentageNullValue() public {}
    function testCannotSetRetainedTreasuryYieldPercentageWithoutPermissions() public {}

    /**
     * Pool Multiplier Percentage get/set.
     */
    function testCanSetPoolMultiplierPercentage() public {}
    function testCannotSetPoolMultiplierPercentageNullValue() public {}
    function testCannotSetPoolMultiplierPercentageWithoutPermissions() public {}

    /**
     * We need to be able to get the equivalent floor token price of another token
     * through using a known pricing executor. For the purposes of this test we can
     * use a Mock.
     */
    function testCanGetTokenFloorPrice() public {}

    /**
     * We should not be able to get the token floor price of a token that UV3 does
     * not recognise. In this case we expect our call to revert.
     */
    function testCannotGetUnknownTokenFloorPrice() public {}

    /**
     * Pricing Executor get/set.
     */
    function testCanGetPricingExecutor() public {}
    function testCanSetPricingExecutor() public {}
    function testCannotSetPricingExecutorWithoutPermissions() public {}

    /**
     * When the epoch ends, the {TreasuryManager} can call to end the epoch. This
     * will generate FLOOR against the token rewards, determine the yield of the
     * {Treasury} to generate additional FLOOR through `RetainedTreasuryYieldPercentage`.
     *
     * We will then need to reference this against the {RewardsLedger} and the
     * {GaugeWeightVote} to confirm that all test users are allocated their correct
     * share.
     *
     * This will be quite a large test. Brace yourselves!
     */
    function testCanEndEpoch() public {}

}
