// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXInventoryStaking {
    function deposit(uint256 vaultId, uint256 _amount) external;
    function withdraw(uint256 vaultId, uint256 _share) external;

    function balanceOf(uint256 vaultId, address who) external view returns (uint256);
    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);
}
