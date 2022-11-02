// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract VaultTest is Test {

    /**
     * Our set up logic deploys our {VaultFactory} contract and creates a valid
     * vault instance that we will subsequently test against.
     */
    function setUp() public {}

    /**
     * This helper function gets the contract address of the collection tied to
     * the vault.
     */
    function testCanGetCollectionAddress() public {}

    /**
     * This helper function gets the strategy address of the collection tied to
     * the vault.
     */
    function testCanGetStrategyAddress() public {}

    /**
     * This helper function gets the vault factory address of the contract that
     * created the vault.
     */
    function testCanGetVaultFactoryAddress() public {}

    /**
     * The vault ID attributed when the vault is created will be made available
     * via this helper function call.
     */
    function testCanGetVaultId() public {}

    /**
     * We should be able to deposit any amount of approved tokens that match
     * the collection contract address. The return value will be the amount
     * of the deposit made, although in reality it is the total of all deposits
     * made by the sender and currently held in contract.
     *
     * Assets should be help in the vault until the strategy calls to stake
     * them.
     */
    function testCanDeposit(uint amount) public {}

    /**
     * A user should be able to make multiple subsequent deposits into the
     * contract. The return value should be the cumulative value of all
     * deposits made in the test.
     */
    function testCanDepositMultipleTimes(uint amount) public {}

    /**
     * If the sender has not approved their token to be transferred, then
     * we should expect a revert.
     */
    function testCannotDepositWithoutApproval() public {}

    /**
     * If the sender does not have a sufficient balance of tokens to be
     * transferred, then we should expect a revert.
     */
    function testCannotDepositWithoutSufficientBalance() public {}

    /**
     * If the sender attempts to send a token to the contract outside of
     * the deposit function, then we should revert it. If the token sent
     * is the same as the collection address, then we can be courteous
     * and try to handle it as a legitimate deposit.
     */
    function testCannotSendTokensOutsideOfDepositCall() public {}

    /**
     * If the sender attempts to send a ETH to the contract then we should
     * just revert the transaction.
     */
    function testCannotSendETH() public {}

    /*---------- DO WE NEED THE BELOW OR JUST EXIT LOGIC? -----------*/

    /**
     * A sender should be able to withdraw from their staked position.
     *
     * Q: Should this only allow for exiting a position?
     */
    function testCanWithdraw(uint amount) public {}

    /**
     * A sender should be able to make multiple withdrawal calls.
     */
    function testCanWithdrawMultipleTimes(uint amount) public {}

    /**
     * If a sender does not has a sufficient balance to withdraw from then
     * we should revert the call.
     */
    function testCannotWithdrawWithoutSufficientBalance() public {}

}
