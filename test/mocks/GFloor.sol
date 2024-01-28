// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Mock} from './erc/ERC20Mock.sol';

contract GFloorMock is ERC20Mock {

    constructor() ERC20Mock() {}

    function balanceFrom(uint _gFloorAmount) public pure returns (uint) {
        return (3983414875 * _gFloorAmount) / 1 ether;
    }

}
