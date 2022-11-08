// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './ERC20.sol';


/**
 * The veFloor token is heavily influenced by the {VeJoeToken} token:
 * https://snowtrace.io/address/0x3cabf341943Bc8466245e4d6F1ae0f8D071a1456#code
 *
 * This contract will need to implement the {VeERC20} interface, in a similar
 * structure to this:
 * https://github.com/traderjoe-xyz/joe-core/blob/9ae7edc7a7920995a2f920d7af1f67887577401a/contracts/VeERC20.sol
 */

interface IVeFLOOR is IERC20 {

    /// @dev Emitted when `value` tokens are burned and minted
    event Burn(address indexed account, uint256 value);
    event Mint(address indexed beneficiary, uint256 value);

    /**
     * Gets the address of the current staking contract attached to the ERC20.
     */
    function stakingContract() external view returns (address);

    /**
     * Creates `_amount` token to `_to`. Must only be called by the owner
     */
    function mint(address to_, uint256 amount_) external;

    /**
     * Destroys `_amount` tokens from `_from`. Callable only by the owner
     */
    function burn(address _from, uint _amount) external;

    /**
     * Sets the address of the staking contract that this token updates.
     */
    function setStakingContract(address _contractAddr) external;

    /**
     * Will need to implement the `_afterTokenOperation` ERC20 function so that whenever
     * tokens are minted or burned.
     *
     * We will also want to ensure that all other operations are reverted, so that the
     * token cannot be transferred or manipulated.
     */

}
