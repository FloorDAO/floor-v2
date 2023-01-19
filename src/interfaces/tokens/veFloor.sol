// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Vote Escrow ERC20 Token Interface.
 *
 * The veFloor token is heavily influenced by the {VeJoeToken} token:
 * https://snowtrace.io/address/0x3cabf341943Bc8466245e4d6F1ae0f8D071a1456#code
 *
 * @notice Interface of a ERC20 token used for vote escrow. Notice that transfers and
 * allowances are disabled.
 */

interface IVeFLOOR {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * Creates `_amount` token to `_to`. Must only be called by the owner.
     *
     * @param _to The address that will receive the mint
     * @param _amount The amount to be minted
     */
    function mint(address _to, uint256 _amount) external;
}
