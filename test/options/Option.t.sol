// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract OptionTest is Test {
    /**
     * Our token expands upon the ERC721 standard, so we need to ensure that
     * we can still access the inherited ERC721 attributes as expected.
     */
    function testCanAccessStandardERC721Attributes() public {}

    /**
     * Our ERC721 has range of functions that provide access to the relevant
     * Option information. These should all return the correct, expected
     * information.
     */
    function testCanGetOptionAttributes() public {}

    /**
     * When our option is updated, our functions should read the updated
     * information and not return anything stale.
     */
    function testCanGetOptionAttributesAfterOptionUpdated() public {}

    /**
     * When specifying an unknown token ID, we should not be able to access a
     * range of functions that provide access to the relevant Option information.
     *
     * We expect in each instance for these calls to be reverted.
     */
    function testCannotGetUnknownOptionAttributes() public {}

    /**
     * Our Option token should be able to generate a dynamic SVG using it's own
     * attribute information.
     *
     * This will be quite difficult to test without just comparing an expected
     * string against the output. We should look at potential ways that we can
     * cherry pick some returned data to test against.
     */
    function testCanGenerateDynamicSVG() public {}

    /**
     * When our ERC721 has been fully actioned, then we should be able to burn
     * it.
     */
    function testCanBurnAFullyActionedOption() public {}

    /**
     * When our ERC721 has not been fully actioned and still has an amount
     * remaining inside of it, then we should not be able to burn it. We
     * should expect a revert when trying.
     */
    function testCannotBurnAnOptionWithRemainingBalance() public {}
}
