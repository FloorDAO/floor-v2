// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXInventoryStaking {

    function inventoryLockTimeErc20() external returns (uint256);

    function __NFTXInventoryStaking_init(address _nftxVaultFactory) external;

    function setTimelockExcludeList(address addr) external;

    function setInventoryLockTimeErc20(uint256 time) external;

    function isAddressTimelockExcluded(address addr, uint256 vaultId) external view returns (bool);

    function deployXTokenForVault(uint256 vaultId) external;

    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);

    function deposit(uint256 vaultId, uint256 _amount) external;

    function timelockMintFor(uint256 vaultId, uint256 amount, address to, uint256 timelockLength) external returns (uint256);

    function withdraw(uint256 vaultId, uint256 _share) external;

    function xTokenShareValue(uint256 vaultId) external view returns (uint256);

    function timelockUntil(uint256 vaultId, address who) external view returns (uint256);

    function balanceOf(uint256 vaultId, address who) external view returns (uint256);

    function xTokenAddr(address baseToken) external view returns (address);

    function vaultXToken(uint256 vaultId) external view returns (address);

}

