// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


interface IVaultXToken is IERC20 {

    /**
     * Creates `_amount` token to `_to`. Must only be called by the owner.
     *
     * @param _to The address that will receive the mint
     * @param _amount The amount to be minted
     */
    function mint(address _to, uint _amount) external;

}
