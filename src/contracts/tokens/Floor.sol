// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import {ERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';

import {AuthorityControl} from '../authorities/AuthorityControl.sol';

import {IFLOOR} from '../../interfaces/tokens/Floor.sol';

/**
 * Sets up our FLOOR ERC20 token.
 */
contract FLOOR is AuthorityControl, ERC20, ERC20Burnable, ERC20Permit, IFLOOR {

    /**
     * Sets up our ERC20 token.
     */
    constructor(address _authority)
        ERC20('Floor', 'FLOOR')
        ERC20Permit('Floor')
        AuthorityControl(_authority) {}

    /**
     * Allows a `FLOOR_MANAGER` to mint additional FLOOR tokens.
     *
     * @param to Recipient of the tokens
     * @param amount Amount of tokens to be minted
     */
    function mint(address to, uint amount) public onlyRole(FLOOR_MANAGER) {
        _mint(to, amount);
    }
}
