# INFTXVaultFactory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/nftx/NFTXVaultFactory.sol)


## Functions
### numVaults


```solidity
function numVaults() external view returns (uint);
```

### zapContract


```solidity
function zapContract() external view returns (address);
```

### zapContracts


```solidity
function zapContracts(address addr) external view returns (bool);
```

### feeDistributor


```solidity
function feeDistributor() external view returns (address);
```

### eligibilityManager


```solidity
function eligibilityManager() external view returns (address);
```

### vault


```solidity
function vault(uint vaultId) external view returns (address);
```

### allVaults


```solidity
function allVaults() external view returns (address[] memory);
```

### vaultsForAsset


```solidity
function vaultsForAsset(address asset) external view returns (address[] memory);
```

### isLocked


```solidity
function isLocked(uint id) external view returns (bool);
```

### excludedFromFees


```solidity
function excludedFromFees(address addr) external view returns (bool);
```

### factoryMintFee


```solidity
function factoryMintFee() external view returns (uint64);
```

### factoryRandomRedeemFee


```solidity
function factoryRandomRedeemFee() external view returns (uint64);
```

### factoryTargetRedeemFee


```solidity
function factoryTargetRedeemFee() external view returns (uint64);
```

### factoryRandomSwapFee


```solidity
function factoryRandomSwapFee() external view returns (uint64);
```

### factoryTargetSwapFee


```solidity
function factoryTargetSwapFee() external view returns (uint64);
```

### vaultFees


```solidity
function vaultFees(uint vaultId) external view returns (uint, uint, uint, uint, uint);
```

### __NFTXVaultFactory_init


```solidity
function __NFTXVaultFactory_init(address _vaultImpl, address _feeDistributor) external;
```

### createVault


```solidity
function createVault(string calldata name, string calldata symbol, address _assetAddress, bool is1155, bool allowAllItems)
    external
    returns (uint);
```

### setFeeDistributor


```solidity
function setFeeDistributor(address _feeDistributor) external;
```

### setEligibilityManager


```solidity
function setEligibilityManager(address _eligibilityManager) external;
```

### setZapContract


```solidity
function setZapContract(address _zapContract, bool _excluded) external;
```

### setFeeExclusion


```solidity
function setFeeExclusion(address _excludedAddr, bool excluded) external;
```

### setFactoryFees


```solidity
function setFactoryFees(uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee) external;
```

### setVaultFees


```solidity
function setVaultFees(uint vaultId, uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee)
    external;
```

### disableVaultFees


```solidity
function disableVaultFees(uint vaultId) external;
```

## Events
### NewFeeDistributor

```solidity
event NewFeeDistributor(address oldDistributor, address newDistributor);
```

### NewZapContract

```solidity
event NewZapContract(address oldZap, address newZap);
```

### UpdatedZapContract

```solidity
event UpdatedZapContract(address zap, bool excluded);
```

### FeeExclusion

```solidity
event FeeExclusion(address feeExcluded, bool excluded);
```

### NewEligibilityManager

```solidity
event NewEligibilityManager(address oldEligManager, address newEligManager);
```

### NewVault

```solidity
event NewVault(uint indexed vaultId, address vaultAddress, address assetAddress);
```

### UpdateVaultFees

```solidity
event UpdateVaultFees(uint vaultId, uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee);
```

### DisableVaultFees

```solidity
event DisableVaultFees(uint vaultId);
```

### UpdateFactoryFees

```solidity
event UpdateFactoryFees(uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee);
```

