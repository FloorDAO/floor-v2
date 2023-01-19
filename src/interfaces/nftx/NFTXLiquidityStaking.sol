// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXLiquidityStaking {
    function nftxVaultFactory() external view returns (address);
    function rewardDistTokenImpl() external view returns (address);
    function stakingTokenProvider() external view returns (address);
    function vaultToken(address _stakingToken) external view returns (address);
    function stakingToken(address _vaultToken) external view returns (address);
    function rewardDistributionToken(uint vaultId) external view returns (address);
    function newRewardDistributionToken(uint vaultId) external view returns (address);
    function oldRewardDistributionToken(uint vaultId) external view returns (address);
    function unusedRewardDistributionToken(uint vaultId) external view returns (address);
    function rewardDistributionTokenAddr(address stakedToken, address rewardToken) external view returns (address);

    // Write functions.
    function receiveRewards(uint vaultId, uint amount) external returns (bool);
    function deposit(uint vaultId, uint amount) external;
    function timelockDepositFor(uint vaultId, address account, uint amount, uint timelockLength) external;
    function exit(uint vaultId, uint amount) external;
    function rescue(uint vaultId) external;
    function withdraw(uint vaultId, uint amount) external;
    function claimRewards(uint vaultId) external;
}
