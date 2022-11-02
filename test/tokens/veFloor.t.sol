// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract VeFloorTest is Test {

    /**
     * Our veFloor should only be able to be minted by our {VoteStaking} contract, so
     * we need to ensure that they are able to call with any positive uint amount to
     * be minted and that it succeeds in sending to the recipient.
     */
    function testCanMint(uint amount) public {}

    /**
     * If no staking contract is set, then we expect a revert.
     */
    function testCannotMintWhenNoStakingContractSet() public {}

    /**
     * If it isn't our staking contract that is calling, then we expect a revert.
     */
    function testCannotMintWithoutPermissions() public {}

    /**
     * Test that we can update the staking contract. Only a governor or guardian should
     * be able to make this call.
     */
    function testCanSetStakingContract() public {}

    /**
     * We should still be able to set our staking contract to a NULL address, which will
     * essentially prevent our minting from working.
     */
    function testCanSetStakingContractToNullAddress() public {}

    /**
     * We need to be able to get the staking contract address in one of three scenarios:
     *  - NULL / no address set
     *  - Address pre-update
     *  - Address post-update
     *
     * Each of these scenarios should still return the address, as there is no expected
     * reverts.
     */
    function testCanGetStakingContract() public {}

    /**
     * Confirm that a non-permitted address cannot update the staking contract.
     */
    function testCannotSetStakingContractWithoutPermissions() public {}

    /**
     * Holders of veFloor should be able to burn their tokens.
     */
    function testCanBurn() public {}

    /**
     * Holders of veFloor should not be able to transfer the tokens. This should result
     * in a revert.
     */
    function testCannotTransfer() public {}

    function testCanSetStakingContract() public {}

    function testMintOrBurnTriggersOperation() public {}

}
