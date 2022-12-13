// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../../src/contracts/options/OptionExchange.sol';

import '../utilities/Environments.sol';


contract OptionExchangeTest is FloorTest {

    OptionExchange exchange;

    /// Store our mainnet fork information
    uint256 mainnetFork;

    /// Capture a block to allow LINK testing
    uint internal constant BLOCK_NUMBER = 16_176_141;

    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    // Chainlink wrapper used for mocking responses
    address private constant VRF_V2_WRAPPER = 0x5A861794B927983406fCE1D062e00b9368d97Df6;

    function setUp() public {
        // Generate a mainnet fork
        mainnetFork = vm.createFork(vm.envString('MAINNET_RPC_URL'));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(BLOCK_NUMBER);

        // Confirm that our block number has set successfully
        assertEq(block.number, BLOCK_NUMBER);

        // Whilst the {Treasury} contract is being developed we can use the Binance8 wallet
        // address as this holds 100,000,000 DAI when the block snapshot was taken. This will
        // mean that we can create a sufficient number of pools with these test funds.
        exchange = new OptionExchange(
            0x6B175474E89094C44Da98b954EedeAC495271d0F,
            LINK,
            VRF_V2_WRAPPER
        );

        // We also need our DAI holding wallet to approve the {OptionExchange} to play with
        // it's funds.
        vm.prank(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        IERC20(DAI).approve(address(exchange), type(uint).max);
    }

    function test_AllocationMethods() public {
        /*
        bytes memory bytesData = abi.encodePacked(
            // Pool ID
            uint(0),

            // Encoded DNA (wDNA)
            keccak256(
                abi.encodePacked(
                    // Recipient
                    address(this),
                    // DNA
                    abi.encodePacked(
                        uint8(10),
                        uint8(5),
                        uint8(1),
                        uint8(0)
                    ),
                    // Index, incremented if multiple of same DNA is
                    // allocated to the user.
                    uint256(0)
                )
            )
        );
        */

        // Create a pool with 10000 DAI
        uint poolId = exchange.createPool(DAI, 10000 ether, uint16(10), uint64(block.timestamp + 60));

        // We must mock the VRF wrapper to return a raw response. The requestId (param 1)
        // doesn't matter, but the random seeds returned will change the output of the
        // allocations being generated.

        uint[] memory randomWords = new uint[](3);
        randomWords[0] = 100;
        randomWords[1] = 200;
        randomWords[2] = 300;

        vm.prank(VRF_V2_WRAPPER);
        exchange.rawFulfillRandomWords(0, randomWords);
    }

    function _test_ExpectThreeRandomWords() public {}

    /**
     * Any user should be able to send then $LINK token to our {OptionExchange} via
     * the provided function. This will likely be members of the internal team, but
     * will be open to any samaritan that may be kind enough to fund the contract.
     */
    function test_CanDepositLinkToken() public {
        // Confirm that our contract starts with 0 LINK
        assertEq(IERC20(LINK).balanceOf(address(exchange)), 0);

        // Connect as a random LINK holder
        vm.startPrank(0x8d4169cCf3aD88EaFBB09580e7441D3eD2b4B922);

        // Approve LINK
        IERC20(LINK).approve(address(exchange), 10e18);

        // Call deposit for 10 tokens
        exchange.depositLink(10e18);

        // Confirm that our contract now holds 10 tokens
        assertEq(IERC20(LINK).balanceOf(address(exchange)), 10e18);

        vm.stopPrank();
    }

    /**
     * When we have a sufficient ERC20 token balance, then our {TreasuryManager}
     * will be able to create a corresponding `OptionPool`.
     */
    function test_CanCreatePool() public {
        uint poolId = exchange.createPool(
            DAI,
            10000 ether,
            uint16(10),
            uint64(block.timestamp + 60)
        );

        // We should have our poolId returned in the response. As this is the first
        // vault created, it will have a 0 index.
        assertEq(poolId, 0);
    }

    /**
     * If we specify an unknown token address when creating our `OptionPool` then
     * we should expect the call to be reverted as we cannot find balance of it.
     */
    function test_CannotCreatePoolWithUnknownToken() public {
        vm.expectRevert();
        exchange.createPool(address(0), 10000 ether, uint16(10), uint64(block.timestamp + 60));
    }

    /**
     *
     */
    function test_CannotCreatePoolWithZeroAmount() public {
        vm.expectRevert('No amount specified');
        exchange.createPool(DAI, 0, uint16(10), uint64(block.timestamp + 60));
    }

    /**
     * If we specify to create an `OptionPool` with an amount above that which is
     * held within the {OptionExchange}, then we expect it to be reverted as we
     * can only allocate that which is readily available.
     */
    function test_CannotCreatePoolWithInsufficientBalance() public {
        vm.expectRevert('Dai/insufficient-balance');
        exchange.createPool(DAI, 1_000_000_000 ether, uint16(10), uint64(block.timestamp + 60));
    }

    /**
     * When creating our `OptionPool` we need to sense check that our discount
     * amount is not set above 100% as we won't have logic in place to send the
     * recipient FLOOR back. Plus, this is just stupid.
     */
    function test_CannotCreatePoolWithDiscountOverOneHundredPercent() public {
        vm.expectRevert('Max discount over 100%');
        exchange.createPool(DAI, 10000 ether, uint16(101), uint64(block.timestamp + 60));
    }

    /**
     * We should not be able to create an `OptionPool` that has already expired
     * as this would prevent any users from being able to action their {Option}.
     */
    function test_CannotCreatePoolWithPastExpiryTimestamp() public {
        vm.expectRevert('Pool already expired');
        exchange.createPool(DAI, 10000 ether, uint16(10), uint64(block.timestamp));
    }

    /**
     * Only our {TreasuryManager} should be able to create a pool. Any other
     * senders should expect a revert.
     */
    function _testCannotCreatePoolWithoutPermissions() public {}

    /**
     * Once an `OptionPool` is created, we should be able to query the index
     * to get back our `OptionPool` struct and access the correct information.
     */
    function _testCanGetOptionPool() public {
        // Create our pool and get our poolId back
        uint poolId = exchange.createPool(DAI, 10000 ether, uint16(10), uint64(block.timestamp + 60));
        assertEq(poolId, 0);

        // Get our pool information from our contract to confirm that all of the
        // entered values are correctly stored.
        OptionExchange.OptionPool memory pool = exchange.getOptionPool(poolId);
        assertEq(pool.amount, 10000 ether);
        assertEq(pool.initialAmount, 10000 ether);
        assertEq(pool.token, DAI);
        assertEq(pool.maxDiscount, 10);
        assertEq(pool.expires, block.timestamp + 60);
        assertEq(pool.initialised, false);
        assertEq(pool.requestId, 0);
    }

    /**
     * Even if an `OptionPool` has been withdrawn or fully actioned, we should
     * still be able to query the defined index and access the correct
     * information. In this test we need to ensure that an `OptionPool` is not
     * deleted.
     */
    function _testCanGetClosedOptionPool() public {}

    /**
     * If we request an `OptionPool` index that doesn't exist, then we should
     * expect our transaction to be reverted.
     */
    function _testCannotGetUnknownOptionPool() public {}

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
    function _testCanGenerateAllocations() public {}

    /**
     * If we try and generate allocations against an unknown pool index, then
     * we expect our transaction to revert.
     */
    function _testCannotGenerateAllocationsForUnknownPool() public {}

    /**
     * It a sender without {TreasuryManager} permissions attempts to generate
     * allocations then we expect the transaction to be reverted.
     */
    function _testCannotGenerateAllocationsWithoutPermissions() public {}

    /**
     * If we have insufficient $LINK tokens in the contract to make our
     * external request, then we want to ensure that our transaction is
     * reverted ahead of our call to prevent further gas loss.
     */
    function _testCanGenerateAllocationsWithoutSufficientLinkToken() public {}

    /**
     * We only want our `fulfillAllocations` call to be callable by the
     * expected ChainLink oracle address. For the purposes of our test case
     * we can just construct our class to have the oracle of test user's
     * wallet.
     */
    function _testCannotFulfillAllocationsWithoutPermissions() public {}

    /**
     * We need to test that when we generate allocations, we will emit the
     * {LinkBalanceLow} event when the $LINK balance held in our contract
     * falls below a set threshold. This test also needs to confirm that we
     * don't sent it when we are above this same threshold.
     */
    function _testCanReceiveLowLinkTokenWarnings() public {}

    /**
     * When a user has an `OptionAllocation` then can mint it. We need to
     * confirm that the {Option} token is minted and tranferred to the user
     * successfully, as well as has the correct attributes attached to it.
     */
    function _testCanMintOptionAllocation() public {}

    /**
     * If a user tries to mint their `OptionAllocation` but specify a pool
     * that doesn't exist, then we expect the transaction to be reverted.
     */
    function _testCannotMintOptionAllocationOfUnknownPool() public {}

    /**
     * If a user tries to mint their `OptionAllocation` but specify a pool
     * that they don't have an allocation in, then we expect the transaction
     * to be reverted.
     */
    function _testCannotMintOptionAllocationForUnknownSender() public {}

    /**
     * When the user has an {Option} ERC721 token, they should be able to
     * action it. The {Option} should hold updated information based on the
     * amount that was actioned and the `OptionPool` should also show that
     * the amount has been reduced.
     *
     * This test will action the full amount of the {Option}.
     */
    function _testCanActionOption() public {}

    /**
     * This test will follow the same steps as the `canActionOption` test,
     * except it will only action a partial amount of the {Option}.
     */
    function _testCanPartiallyActionOption() public {}

    /**
     * If our {Option} doesn't have any discount, we should still be able
     * action it and will just allow for the exact claim of the amount
     * allocated.
     */
    function _testCanActionOptionWithoutDiscount() public {}

    /**
     * As we can't simply trust the `floorIn` and `tokenOut` amounts
     * provided by the user, we will need to
     *
     * For this test, we can make hardcoded calls that will fall below
     * the approved movement boundaries.
     */
    function _testCanActionOptionWithinApprovedMovementContraints() public {}

    /**
     * If the sender specifies an unminted {Option} token ID then we
     * expect the transaction to be reverted.
     */
    function _testCannotActionUnknownOption() public {}

    /**
     * If the {Option} belongs to an `OptionPool` that has expired
     * then we expect the transaction to be reverted.
     */
    function _testCannotActionExpiredOption() public {}

    /**
     * If the sender provides the `tokenId` of an {Option} that they
     * do not own, then we expect the transaction to be reverted.
     */
    function _testCannotActionOptionThatSenderDoesNotOwn() public {}

    /**
     * If the sender does not have an approve FLOOR balance that would
     * sufficiently cover their `floorIn` amount, then we expect the
     * transaction to be reverted.
     */
    function _testCannotActionOptionWithUnapprovedFloor() public {}

    /**
     * If the sender has approved FLOOR, but has insufficient balance
     * to fulfill the action, then we expect the transaction to be
     * reverted.
     */
    function _testCannotActionOptionWithSenderHoldingInsufficientFloor() public {}

    /**
     * If the sender tries to claim more in `tokenOut` that then the
     * {Option} allocation permits, then we expect the transaction to
     * be reverted.
     */
    function _testCannotActionOptionAboveAllocationAmount() public {}

    /**
     * If our calculated price is above the `approvedMovement` percent
     * then we expect the transaction to revert.
     */
    function _testCannotActionOptionBelowApprovedMovement() public {}

    /**
     * If our calculated price is below the `approvedMovement` percent
     * then we expect the transaction to revert.
     */
    function _testCannotActionOptionAboveApprovedMovement() public {}

    /**
     * We should be able to query our {Treasury} to get the price of
     * FLOOR <> token. This is required for our frontend and contract
     * to both be able to find the amount of FLOOR required to claim
     * the `tokenOut` requested.
     */
    function _testCanGetRequiredFloorPriceForToken() public {}

    /**
     * If an unknown token is requested, then we expect our call to
     * be reverted as we won't have a price returned.
     */
    function _testCannotGetRequiredFloorPriceForUnknownToken() public {}

    /**
     * A sender should be able to get a list of `OptionAllocation`s
     * that they can mint. Once minted, these will no longer be
     * returned in this call.
     */
    function _testCanGetClaimableOptions() public {}

    /**
     * Even if the sender has no `OptionAllocation` assigned to their
     * address, they will still receive a response but it will just
     * be an empty array.
     */
    function _testCanGetClaimableOptionsForUnknownSender() public {}

    /**
     * The default FLOOR recipient for the contract will be a null
     * address to ensure that the token is burnt when received by the
     * {OptionExchange}. We need to ensure that this address can be
     * updated and that the address receives the FLOOR tokens exchanged
     * moving forward.
     */
    function _testCanSetFloorRecipient() public {}

    /**
     * Only our {TreasuryManager} should be able to set a new FLOOR
     * recipient, so we need to ensure that other senders cannot call
     * the function.
     */
    function _testCannotSetFloorRecipientWithoutPermissions() public {}

    /**
     * We only want tokens to be sent through either our `deposit` or
     * `depositLink` functions. For this reason we want to prevent
     * direct token transfers as this would render them lost inside
     * of the contract.
     */
    function _testCannotSendTokensDirectlyToContract() public {}

    /**
     * At no point will we want to offer ETH in an {Option}, so we
     * want to prevent ETH coming in to the contract.
     */
    function _testCannotSendETHToContract() public {}

    function test_CanCalculateRarity() public {
        assertEq(exchange.rarity_score(0, 0, 20), 0);
        assertEq(exchange.rarity_score(20, 20, 20), 100);
        assertEq(exchange.rarity_score(10, 10, 20), 50);
        assertEq(exchange.rarity_score(20, 10, 20), 75);
        assertEq(exchange.rarity_score(10, 20, 20), 75);
        assertEq(exchange.rarity_score(5, 5, 20), 25);
        assertEq(exchange.rarity_score(15, 15, 20), 75);
    }

}
