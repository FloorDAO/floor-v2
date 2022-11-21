// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract MigrationFloorTokenTest is Test {

    /**
     * There are a range of V1 tokens that we will need to accept:
     *
     *  - aFloor (alpha token, should already be converted into floor)
     *  - Floor (core token)
     *  - gFloor (governance floor)
     *  - sFloor (staked floor)
     *
     * We will need to ensure each of these are accepted and mint at
     * a 1:1 ratio.
     *
     * The Floor V1 tokens should be burnt.
     */
    function testCanMigrateAllAcceptedV1TokensToV2() public {}

    /**
     * A user needs to be able to upgrade a partial amount of
     * their existing Floor V1 tokens and receive the exact same
     * amount of Floor V2 tokens back.
     *
     * The Floor V1 tokens should be burnt.
     */
    function testCanPartiallyUpgradeFloorTokenToV2() public {}

    /**
     * A user needs to be able to upgrade their entire V1 balance
     * receive the exact same amount of Floor V2 tokens back.
     *
     * The Floor V1 tokens should be burnt.
     */
    function testCanFullyUpgradeFloorTokenToV2(uint amount) public {}

    /**
     * If a user does not have a sufficient Floor V1 token balance
     * then the transaction should be reverted.
     */
    function testCannotUpgradeWithInsufficientBalance() public {}

    /**
     * If a user has not approved the contract to handle their
     * Floor V1 tokens, then the transaction should be reverted.
     */
    function testCannotUpgradeIfNotApproved() public {}

    /**
     * If a user opts to, they can additionally automatically stake
     * their migrated floor token through {VoteStaking}. This will
     * result in veFloor being transferred for the user in addition
     * to receiving their Floor.
     */
    function testCanStakeMigratedFloor() public {}

}
