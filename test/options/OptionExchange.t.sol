// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract OptionExchangeTest is Test {

    /**
     * Our {TreasuryManager} should be able to call our `deposit` function to transfer
     * assets from the {Treasury} into the {OptionsExchange}. No pools should be set up
     * at this point, only the transfer of ERC20 tokens.
     */
    function canDeposit() public {}

    /**
     * If a non-{TreasuryManager} attempts to call our deposit function we should
     * expect it to be reverted.
     */
    function cannotDepositWithoutPermissions() public {}

    /**
     * If we have insufficient balance of the specified token in the {Treasury} then
     * we should expect the call to be reverted.
     */
    function cannotDepositTokenWithoutSufficientTreasuryBacking() public {}

    /**
     * Any user should be able to send then $LINK token to our {OptionExchange} via
     * the provided function. This will likely be members of the internal team, but
     * will be open to any samaritan that may be kind enough to fund the contract.
     */
    function canDepositLinkToken() public {}

    /**
     * When we have a sufficient ERC20 token balance, then our {TreasuryManager}
     * will be able to create a corresponding `OptionPool`.
     */
    function canCreatePool() public {}

    /**
     * If we specify an unknown token address when creating our `OptionPool` then
     * we should expect the call to be reverted as we cannot find balance of it.
     */
    function cannotCreatePoolWithUnknownToken() public {}

    /**
     * If we specify to create an `OptionPool` with an amount above that which is
     * held within the {OptionExchange}, then we expect it to be reverted as we
     * can only allocate that which is readily available.
     */
    function cannotCreatePoolWithInsufficientBalance() public {}

    /**
     * When creating our `OptionPool` we need to sense check that our discount
     * amount is not below 0%. We shouldn't be able to do this as our integer
     * is unsigned, but still good to know we have our bases covered.
     */
    function cannotCreatePoolWithNegativeDiscount() public {}

    /**
     * When creating our `OptionPool` we need to sense check that our discount
     * amount is not set above 100% as we won't have logic in place to send the
     * recipient FLOOR back. Plus, this is just stupid.
     */
    function cannotCreatePoolWithDiscountOverOneHundredPercent() public {}

    /**
     * We should not be able to create an `OptionPool` that has already expired
     * as this would prevent any users from being able to action their {Option}.
     */
    function cannotCreatePoolWithPastExpiryTimestamp() public {}

    /**
     * Only our {TreasuryManager} should be able to create a pool. Any other
     * senders should expect a revert.
     */
    function cannotCreatePoolWithoutPermissions() public {}

    /**
     * Once an `OptionPool` is created, we should be able to query the index
     * to get back our `OptionPool` struct and access the correct information.
     */
    function canGetOptionPool() public {}

    /**
     * Even if an `OptionPool` has been withdrawn or fully actioned, we should
     * still be able to query the defined index and access the correct
     * information. In this test we need to ensure that an `OptionPool` is not
     * deleted.
     */
    function canGetClosedOptionPool() public {}

    /**
     * If we request an `OptionPool` index that doesn't exist, then we should
     * expect our transaction to be reverted.
     */
    function cannotGetUnknownOptionPool() public {}

    /**
     * Our {TreasuryManager} should be able to generate allocations against an
     * `OptionPool`. Since our real-world scenario would return a randomised
     * response, we will need to use a Mock to ensure that the generated data
     * is persisted for testing.
     *
     * This will be one of the larger tests, as to confirm that the function
     * correctly generates and allocates data we will need to inherintly test
     * the `fulfillAllocations` function, as well as the
     * `claimableOptionAllocations` function.
     */
    function canGenerateAllocations() public {}

    /**
     * If we try and generate allocations against an unknown pool index, then
     * we expect our transaction to revert.
     */
    function cannotGenerateAllocationsForUnknownPool() public {}

    /**
     * It a sender without {TreasuryManager} permissions attempts to generate
     * allocations then we expect the transaction to be reverted.
     */
    function cannotGenerateAllocationsWithoutPermissions() public {}

    /**
     * If we have insufficient $LINK tokens in the contract to make our
     * external request, then we want to ensure that our transaction is
     * reverted ahead of our call to prevent further gas loss.
     */
    function canGenerateAllocationsWithoutSufficientLinkToken() public {}

    /**
     * We only want our `fulfillAllocations` call to be callable by the
     * expected ChainLink oracle address. For the purposes of our test case
     * we can just construct our class to have the oracle of test user's
     * wallet.
     */
    function cannotFulfillAllocationsWithoutPermissions() public {}

    /**
     * We need to test that when we generate allocations, we will emit the
     * {LinkBalanceLow} event when the $LINK balance held in our contract
     * falls below a set threshold. This test also needs to confirm that we
     * don't sent it when we are above this same threshold.
     */
    function canReceiveLowLinkTokenWarnings() public {}

    /**
     * When a user has an `OptionAllocation` then can mint it. We need to
     * confirm that the {Option} token is minted and tranferred to the user
     * successfully, as well as has the correct attributes attached to it.
     */
    function canMintOptionAllocation() public {}

    /**
     * If a user tries to mint their `OptionAllocation` but specify a pool
     * that doesn't exist, then we expect the transaction to be reverted.
     */
    function cannotMintOptionAllocationOfUnknownPool() public {}

    /**
     * If a user tries to mint their `OptionAllocation` but specify a pool
     * that they don't have an allocation in, then we expect the transaction
     * to be reverted.
     */
    function cannotMintOptionAllocationForUnknownSender() public {}

    /**
     * When the user has an {Option} ERC721 token, they should be able to
     * action it. The {Option} should hold updated information based on the
     * amount that was actioned and the `OptionPool` should also show that
     * the amount has been reduced.
     *
     * This test will action the full amount of the {Option}.
     */
    function canActionOption() public {}

    /**
     * This test will follow the same steps as the `canActionOption` test,
     * except it will only action a partial amount of the {Option}.
     */
    function canPartiallyActionOption() public {}

    /**
     * If our {Option} doesn't have any discount, we should still be able
     * action it and will just allow for the exact claim of the amount
     * allocated.
     */
    function canActionOptionWithoutDiscount() public {}

    /**
     * As we can't simply trust the `floorIn` and `tokenOut` amounts
     * provided by the user, we will need to
     *
     * For this test, we can make hardcoded calls that will fall below
     * the approved movement boundaries.
     */
    function canActionOptionWithinApprovedMovementContraints() public {}

    /**
     * If the sender specifies an unminted {Option} token ID then we
     * expect the transaction to be reverted.
     */
    function cannotActionUnknownOption() public {}

    /**
     * If the {Option} belongs to an `OptionPool` that has expired
     * then we expect the transaction to be reverted.
     */
    function cannotActionExpiredOption() public {}

    /**
     * If the sender provides the `tokenId` of an {Option} that they
     * do not own, then we expect the transaction to be reverted.
     */
    function cannotActionOptionThatSenderDoesNotOwn() public {}

    /**
     * If the sender does not have an approve FLOOR balance that would
     * sufficiently cover their `floorIn` amount, then we expect the
     * transaction to be reverted.
     */
    function cannotActionOptionWithUnapprovedFloor() public {}

    /**
     * If the sender has approved FLOOR, but has insufficient balance
     * to fulfill the action, then we expect the transaction to be
     * reverted.
     */
    function cannotActionOptionWithSenderHoldingInsufficientFloor() public {}

    /**
     * If the sender tries to claim more in `tokenOut` that then the
     * {Option} allocation permits, then we expect the transaction to
     * be reverted.
     */
    function cannotActionOptionAboveAllocationAmount() public {}

    /**
     * If our calculated price is above the `approvedMovement` percent
     * then we expect the transaction to revert.
     */
    function cannotActionOptionBelowApprovedMovement() public {}

    /**
     * If our calculated price is below the `approvedMovement` percent
     * then we expect the transaction to revert.
     */
    function cannotActionOptionAboveApprovedMovement() public {}

    /**
     * We should be able to query our {Treasury} to get the price of
     * FLOOR <> token. This is required for our frontend and contract
     * to both be able to find the amount of FLOOR required to claim
     * the `tokenOut` requested.
     */
    function canGetRequiredFloorPriceForToken() public {}

    /**
     * If an unknown token is requested, then we expect our call to
     * be reverted as we won't have a price returned.
     */
    function cannotGetRequiredFloorPriceForUnknownToken() public {}

    /**
     * A sender should be able to get a list of `OptionAllocation`s
     * that they can mint. Once minted, these will no longer be
     * returned in this call.
     */
    function canGetClaimableOptions() public {}

    /**
     * Even if the sender has no `OptionAllocation` assigned to their
     * address, they will still receive a response but it will just
     * be an empty array.
     */
    function canGetClaimableOptionsForUnknownSender() public {}

    /**
     * The default FLOOR recipient for the contract will be a null
     * address to ensure that the token is burnt when received by the
     * {OptionExchange}. We need to ensure that this address can be
     * updated and that the address receives the FLOOR tokens exchanged
     * moving forward.
     */
    function canSetFloorRecipient() public {}

    /**
     * Only our {TreasuryManager} should be able to set a new FLOOR
     * recipient, so we need to ensure that other senders cannot call
     * the function.
     */
    function cannotSetFloorRecipientWithoutPermissions() public {}

    /**
     * We only want tokens to be sent through either our `deposit` or
     * `depositLink` functions. For this reason we want to prevent
     * direct token transfers as this would render them lost inside
     * of the contract.
     */
    function cannotSendTokensDirectlyToContract() public {}

    /**
     * At no point will we want to offer ETH in an {Option}, so we
     * want to prevent ETH coming in to the contract.
     */
    function cannotSendETHToContract() public {}

}
