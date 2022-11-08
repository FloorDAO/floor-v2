// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract TreasuryTest is Test {

    /**
     * Checks that an authorised user can an arbritrary amount of floor.
     *
     * This should emit {FloorMinted}.
     */
    function canMintFloor(uint amount) public {}

    /**
     * Ensure that only the {TreasuryManager} can action the minting of floor.
     *
     * This should not emit {FloorMinted}.
     */
    function cannotMintFloorWithoutPermissions() public {}

    /**
     * We should validate the amount passed into the floor minting to ensure that
     * a zero value cannot be requested.
     *
     * This should not emit {FloorMinted}.
     */
    function cannotMintZeroFloor() public {}

    /**
     * We should be able to mint the floor token equivalent of a token, based on
     * the internally stored conversion value.
     *
     * This should emit {FloorMinted}.
     */
    function canMintTokenFloor(uint amount) public {}

    /**
     * We should be able to mint floor against an unbacked token, as the token
     * can be held in an external platform as unclaimed reward yield.
     */
    function canMintUnbackedTokenFloor() public {}

    /**
     * TODO
     */
    function cannotMintZeroTokenFloor() public {}

    /**
     * TODO
     */
    function cannotMintTokenFloorWithoutPrice() public {}

    /**
     * TODO
     */
    function canDepositNativeToken() public {}

    /**
     * TODO
     */
    function canDepositERC20() public {}

    /**
     * TODO
     */
    function cannotDepositInvalidERC20() public {}

    /**
     * TODO
     */
    function canDepositERC721() public {}

    /**
     * TODO
     */
    function cannotDepositInvalidERC721() public {}

    /**
     * TODO
     */
    function canWithdrawNativeToken() public {}

    /**
     * TODO
     */
    function cannotWithdrawNativeTokenWithoutPermissions() public {}

    /**
     * TODO
     */
    function canWithdrawERC20() public {}

    /**
     * TODO
     */
    function cannotWithdrawInvalidERC20() public {}

    /**
     * TODO
     */
    function cannotWithdrawERC20WithoutPermissions() public {}

    /**
     * TODO
     */
    function canWithdrawERC721() public {}

    /**
     * TODO
     */
    function cannotWithdrawInvalidERC721() public {}

    /**
     * TODO
     */
    function cannotWithdrawERC721WithoutPermissions() public {}

    /**
     * TODO
     */
    function canSetRewardsLedgerContract() public {}

    /**
     * TODO
     */
    function cannotSetRewardsLedgerContractNullValue() public {}

    /**
     * TODO
     */
    function cannotSetRewardsLedgerContractWithoutPermissions() public {}

    /**
     * TODO
     */
    function canSetGaugeWeightVoteContract() public {}

    /**
     * TODO
     */
    function cannotSetGaugeWeightVoteContractNullValue() public {}

    /**
     * TODO
     */
    function cannotSetGaugeWeightVoteContractWithoutPermissions() public {}

    /**
     * TODO
     */
    function canSetRetainedTreasuryYieldPercentage() public {}

    /**
     * TODO
     */
    function cannotSetRetainedTreasuryYieldPercentageNullValue() public {}

    /**
     * TODO
     */
    function cannotSetRetainedTreasuryYieldPercentageWithoutPermissions() public {}

    /**
     * TODO
     */
    function canSetPoolMultiplierPercentage() public {}

    /**
     * TODO
     */
    function cannotSetPoolMultiplierPercentageNullValue() public {}

    /**
     * TODO
     */
    function cannotSetPoolMultiplierPercentageWithoutPermissions() public {}

    /**
     * TODO
     */
    function canPauseFloorMinting() public {}

    /**
     * TODO
     */
    function cannotPauseFloorMintingWithoutPermissions() public {}

    /**
     * TODO
     */
    function canUnpauseFloorMinting() public {}

    /**
     * TODO
     */
    function canUnpauseFloorMintingWithoutPermissions() public {}

    /**
     * TODO
     */
    function canGetTokenFloorPrice() public {}

    /**
     * TODO
     */
    function cannotGetUnknownTokenFloorPrice() public {}

    /**
     * TODO
     */
    function canSetTrustedContract() public {}

    /**
     * TODO
     */
    function cannotSetTrustedContractWithoutPermissions() public {}

    /**
     * TODO
     */
    function canGetPricingExecutor() public {}

    /**
     * TODO
     */
    function canSetPricingExecutor() public {}

    /**
     * TODO
     */
    function cannotSetPricingExecutorWithoutPermissions() public {}

    /**
     * TODO
     */
    function canEndEpoch() public {}

}
