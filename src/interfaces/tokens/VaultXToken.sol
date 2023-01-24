// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IVaultXToken {

    /// @dev This event MUST emit when target is distributed to token holders.
    /// @param from The address which sends target to this contract.
    /// @param weiAmount The amount of distributed target in wei.
    event RewardsDistributed(address indexed from, uint256 weiAmount);

    /// @dev This event MUST emit when an address withdraws their dividend.
    /// @param to The address which withdraws target from this contract.
    /// @param weiAmount The amount of withdrawn target in wei.
    event RewardWithdrawn(address indexed to, uint256 weiAmount);

    function mint(address account, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function distributeRewards(uint amount) external;

    function withdrawReward(address user) external;

    function dividendOf(address _owner) external view returns(uint256);

    function withdrawnRewardOf(address _owner) external view returns(uint256);

    function accumulativeRewardOf(address _owner) external view returns(uint256);

}
