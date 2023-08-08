// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IWETH is IERC20 {
    function allowance(address, address) external view returns (uint);

    function balanceOf(address) external view returns (uint);

    function approve(address, uint) external returns (bool);

    function transfer(address, uint) external returns (bool);

    function transferFrom(address, address, uint) external returns (bool);

    function deposit() external payable;

    function withdraw(uint) external;
}
