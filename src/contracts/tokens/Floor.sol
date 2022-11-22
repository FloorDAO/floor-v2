// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import '../authorities/AuthorityControl.sol';
import '../../interfaces/tokens/Floor.sol';


contract FLOOR is AuthorityControl, ERC20, ERC20Burnable, ERC20Permit, IFLOOR {

    constructor (address _authority) ERC20('Floor', 'FLOOR') ERC20Permit('Floor') AuthorityControl(_authority) {}

    function mint(address to, uint256 amount) public onlyRole(FLOOR_MANAGER) {
        _mint(to, amount);
    }

}
