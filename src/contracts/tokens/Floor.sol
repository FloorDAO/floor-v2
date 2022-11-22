// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import '../authorities/AuthorityManager.sol';
import '../../interfaces/tokens/Floor.sol';


contract FLOOR is ERC20, ERC20Burnable, ERC20Permit, AuthorityManager, IFLOOR {

    bytes32 public constant ROLE = keccak256('FloorMinter');

    constructor() ERC20('Floor', 'FLOOR') ERC20Permit('Floor') {}

    function mint(address to, uint256 amount) public onlyRole(ROLE) {
        _mint(to, amount);
    }

}
