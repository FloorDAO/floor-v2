// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface INFTXInventoryStaking {

    function deposit(uint256 vaultId, uint256 _amount) external;
    function withdraw(uint256 vaultId, uint256 _share) external;

}
