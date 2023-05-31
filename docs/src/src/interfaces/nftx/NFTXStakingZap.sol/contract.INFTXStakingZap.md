# INFTXStakingZap
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/nftx/NFTXStakingZap.sol)


## Functions
### lpLockTime


```solidity
function lpLockTime() external returns (uint);
```

### inventoryLockTime


```solidity
function inventoryLockTime() external returns (uint);
```

### assignStakingContracts


```solidity
function assignStakingContracts() external;
```

### setTimelockExcludeList


```solidity
function setTimelockExcludeList(address addr) external;
```

### setLPLockTime


```solidity
function setLPLockTime(uint newLPLockTime) external;
```

### setInventoryLockTime


```solidity
function setInventoryLockTime(uint newInventoryLockTime) external;
```

### isAddressTimelockExcluded


```solidity
function isAddressTimelockExcluded(address addr, uint vaultId) external view returns (bool);
```

### provideInventory721


```solidity
function provideInventory721(uint vaultId, uint[] calldata tokenIds) external;
```

### provideInventory1155


```solidity
function provideInventory1155(uint vaultId, uint[] calldata tokenIds, uint[] calldata amounts) external;
```

### addLiquidity721ETH


```solidity
function addLiquidity721ETH(uint vaultId, uint[] calldata ids, uint minWethIn) external payable returns (uint);
```

### addLiquidity721ETHTo


```solidity
function addLiquidity721ETHTo(uint vaultId, uint[] memory ids, uint minWethIn, address to) external payable returns (uint);
```

### addLiquidity1155ETH


```solidity
function addLiquidity1155ETH(uint vaultId, uint[] calldata ids, uint[] calldata amounts, uint minEthIn) external payable returns (uint);
```

### addLiquidity1155ETHTo


```solidity
function addLiquidity1155ETHTo(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minEthIn, address to)
    external
    payable
    returns (uint);
```

### addLiquidity721


```solidity
function addLiquidity721(uint vaultId, uint[] calldata ids, uint minWethIn, uint wethIn) external returns (uint);
```

### addLiquidity721To


```solidity
function addLiquidity721To(uint vaultId, uint[] memory ids, uint minWethIn, uint wethIn, address to) external returns (uint);
```

### addLiquidity1155


```solidity
function addLiquidity1155(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minWethIn, uint wethIn) external returns (uint);
```

### addLiquidity1155To


```solidity
function addLiquidity1155To(uint vaultId, uint[] memory ids, uint[] memory amounts, uint minWethIn, uint wethIn, address to)
    external
    returns (uint);
```

### rescue


```solidity
function rescue(address token) external;
```

