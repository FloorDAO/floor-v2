// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXInventoryStaking {
    function deposit(uint vaultId, uint _amount) external;
    function withdraw(uint vaultId, uint _share) external;

    function balanceOf(uint vaultId, address who) external view returns (uint);
    function receiveRewards(uint vaultId, uint amount) external returns (bool);
}
