// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract TransferTreasuryFundsAndGenerateAllocationsZapTest is Test {

    /**
     * When setting up our zap, we will require our {Treasury} and {OptionExchange}
     * to be deployed and available.
     *
     * Since this logic is only concatenating pre-existing {OptionExchange} logic, we
     * assume that they are each individually tested in the {OptionExchange} test suite.
     *
     * For this reason we don't need to test the full range of invalid parameters for
     * different failing user journeys and can just confirm the happy path.
     */
    function setUp() public {}

    /**
     * We need to ensure that we can successfully run our zap to completion.
     */
    function testCanExecute() public {}

    /**
     * Test that the calling user must have the {TreasuryManager} permissions.
     */
    function testCannotExecuteWithoutPermissions() public {}

}
