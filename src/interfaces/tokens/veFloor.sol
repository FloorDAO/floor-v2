// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './ERC20.sol';


/**
 * https://snowtrace.io/address/0x3cabf341943Bc8466245e4d6F1ae0f8D071a1456#code
 */

interface IVeFLOOR is IERC20 {

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
