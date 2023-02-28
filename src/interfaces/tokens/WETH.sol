// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

abstract contract IWETH is IERC20 {
    function allowance(address, address) public view virtual returns (uint);

    function balanceOf(address) public view virtual returns (uint);

    function approve(address, uint) public virtual returns (bool);

    function transfer(address, uint) public virtual returns (bool);

    function transferFrom(address, address, uint) public virtual returns (bool);

    function deposit() public payable virtual;

    function withdraw(uint) public virtual;
}
