// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';


interface IVaultXToken {
    /// @dev This event MUST emit when target is distributed to token holders.
    /// @param from The address which sends target to this contract.
    /// @param weiAmount The amount of distributed target in wei.
    event RewardsDistributed(address indexed from, uint weiAmount);

    /// @dev This event MUST emit when an address withdraws their dividend.
    /// @param to The address which withdraws target from this contract.
    /// @param weiAmount The amount of withdrawn target in wei.
    event RewardWithdrawn(address indexed to, uint weiAmount);

    function target() external returns (IERC20);

    function mint(address account, uint amount) external;

    function burnFrom(address account, uint amount) external;

    function distributeRewards(uint amount) external;

    function withdrawReward(address user) external;

    function dividendOf(address _owner) external view returns (uint);

    function withdrawnRewardOf(address _owner) external view returns (uint);

    function accumulativeRewardOf(address _owner) external view returns (uint);
}
