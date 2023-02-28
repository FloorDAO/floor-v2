// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXInventoryStaking {
    function inventoryLockTimeErc20() external returns (uint);

    function __NFTXInventoryStaking_init(address _nftxVaultFactory) external;

    function setTimelockExcludeList(address addr) external;

    function setInventoryLockTimeErc20(uint time) external;

    function isAddressTimelockExcluded(address addr, uint vaultId) external view returns (bool);

    function deployXTokenForVault(uint vaultId) external;

    function receiveRewards(uint vaultId, uint amount) external returns (bool);

    function deposit(uint vaultId, uint _amount) external;

    function timelockMintFor(uint vaultId, uint amount, address to, uint timelockLength) external returns (uint);

    function withdraw(uint vaultId, uint _share) external;

    function xTokenShareValue(uint vaultId) external view returns (uint);

    function timelockUntil(uint vaultId, address who) external view returns (uint);

    function balanceOf(uint vaultId, address who) external view returns (uint);

    function xTokenAddr(address baseToken) external view returns (address);

    function vaultXToken(uint vaultId) external view returns (address);
}
