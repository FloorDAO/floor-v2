// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.7.5;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IgFLOOR is IERC20 {
    function mint(address _to, uint _amount) external;

    function burn(address _from, uint _amount) external;

    function index() external view returns (uint);

    function balanceFrom(uint _amount) external view returns (uint);

    function balanceTo(uint _amount) external view returns (uint);
}
