// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXStakingZap {
    function lpLockTime() external returns (uint);

    function inventoryLockTime() external returns (uint);

    function assignStakingContracts() external;

    function setTimelockExcludeList(address addr) external;

    function setLPLockTime(uint newLPLockTime) external;

    function setInventoryLockTime(uint newInventoryLockTime) external;

    function isAddressTimelockExcluded(address addr, uint vaultId) external view returns (bool);

    function provideInventory721(uint vaultId, uint[] calldata tokenIds) external;

    function provideInventory1155(uint vaultId, uint[] calldata tokenIds, uint[] calldata amounts) external;

    function addLiquidity721ETH(uint vaultId, uint[] calldata ids, uint minWethIn) external payable returns (uint);

    function addLiquidity721ETHTo(uint vaultId, uint[] memory ids, uint minWethIn, address to) external payable returns (uint);

    function addLiquidity1155ETH(uint vaultId, uint[] calldata ids, uint[] calldata amounts, uint minEthIn)
        external
        payable
        returns (uint);

    function addLiquidity1155ETHTo(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minEthIn, address to)
        external
        payable
        returns (uint);

    function addLiquidity721(uint vaultId, uint[] calldata ids, uint minWethIn, uint wethIn) external returns (uint);

    function addLiquidity721To(uint vaultId, uint[] memory ids, uint minWethIn, uint wethIn, address to) external returns (uint);

    function addLiquidity1155(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minWethIn, uint wethIn)
        external
        returns (uint);

    function addLiquidity1155To(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minWethIn, uint wethIn, address to)
        external
        returns (uint);

    function rescue(address token) external;
}
