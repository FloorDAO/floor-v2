# INFTXInventoryStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/nftx/NFTXInventoryStaking.sol)


## Functions
### inventoryLockTimeErc20


```solidity
function inventoryLockTimeErc20() external returns (uint);
```

### __NFTXInventoryStaking_init


```solidity
function __NFTXInventoryStaking_init(address _nftxVaultFactory) external;
```

### setTimelockExcludeList


```solidity
function setTimelockExcludeList(address addr) external;
```

### setInventoryLockTimeErc20


```solidity
function setInventoryLockTimeErc20(uint time) external;
```

### isAddressTimelockExcluded


```solidity
function isAddressTimelockExcluded(address addr, uint vaultId) external view returns (bool);
```

### deployXTokenForVault


```solidity
function deployXTokenForVault(uint vaultId) external;
```

### receiveRewards


```solidity
function receiveRewards(uint vaultId, uint amount) external returns (bool);
```

### deposit


```solidity
function deposit(uint vaultId, uint _amount) external;
```

### timelockMintFor


```solidity
function timelockMintFor(uint vaultId, uint amount, address to, uint timelockLength) external returns (uint);
```

### withdraw


```solidity
function withdraw(uint vaultId, uint _share) external;
```

### xTokenShareValue


```solidity
function xTokenShareValue(uint vaultId) external view returns (uint);
```

### timelockUntil


```solidity
function timelockUntil(uint vaultId, address who) external view returns (uint);
```

### balanceOf


```solidity
function balanceOf(uint vaultId, address who) external view returns (uint);
```

### xTokenAddr


```solidity
function xTokenAddr(address baseToken) external view returns (address);
```

### vaultXToken


```solidity
function vaultXToken(uint vaultId) external view returns (address);
```

