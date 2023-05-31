# INFTXVault
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/nftx/NFTXVault.sol)


## Functions
### manager


```solidity
function manager() external view returns (address);
```

### assetAddress


```solidity
function assetAddress() external view returns (address);
```

### is1155


```solidity
function is1155() external view returns (bool);
```

### allowAllItems


```solidity
function allowAllItems() external view returns (bool);
```

### enableMint


```solidity
function enableMint() external view returns (bool);
```

### enableRandomRedeem


```solidity
function enableRandomRedeem() external view returns (bool);
```

### enableTargetRedeem


```solidity
function enableTargetRedeem() external view returns (bool);
```

### enableRandomSwap


```solidity
function enableRandomSwap() external view returns (bool);
```

### enableTargetSwap


```solidity
function enableTargetSwap() external view returns (bool);
```

### vaultId


```solidity
function vaultId() external view returns (uint);
```

### nftIdAt


```solidity
function nftIdAt(uint holdingsIndex) external view returns (uint);
```

### allHoldings


```solidity
function allHoldings() external view returns (uint[] memory);
```

### totalHoldings


```solidity
function totalHoldings() external view returns (uint);
```

### mintFee


```solidity
function mintFee() external view returns (uint);
```

### randomRedeemFee


```solidity
function randomRedeemFee() external view returns (uint);
```

### targetRedeemFee


```solidity
function targetRedeemFee() external view returns (uint);
```

### randomSwapFee


```solidity
function randomSwapFee() external view returns (uint);
```

### targetSwapFee


```solidity
function targetSwapFee() external view returns (uint);
```

### vaultFees


```solidity
function vaultFees() external view returns (uint, uint, uint, uint, uint);
```

### redeem


```solidity
function redeem(uint amount, uint[] calldata specificIds) external returns (uint[] calldata);
```

### redeemTo


```solidity
function redeemTo(uint amount, uint[] calldata specificIds, address to) external returns (uint[] calldata);
```

