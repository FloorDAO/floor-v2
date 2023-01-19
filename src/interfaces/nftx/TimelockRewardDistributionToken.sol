// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITimelockRewardDistributionToken {
    function distributeRewards(uint amount) external;
    function mint(address account, address to, uint amount) external;
    function timelockMint(address account, uint amount, uint timelockLength) external;
    function burnFrom(address account, uint amount) external;
    function withdrawReward(address user) external;
    function dividendOf(address _owner) external view returns (uint);
    function withdrawnRewardOf(address _owner) external view returns (uint);
    function accumulativeRewardOf(address _owner) external view returns (uint);
    function timelockUntil(address account) external view returns (uint);
}
