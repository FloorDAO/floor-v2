# IVaultFactory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/vaults/VaultFactory.sol)

Allows for vaults to be created, pairing them with a {Strategy} and an approved
collection. The vault creation script needs to be as highly optimised as possible
to ensure that the gas costs are kept down.
This factory will keep an index of created vaults and secondary information to ensure
that external applications can display and maintain a list of available vaults.
The contract can be paused to prevent the creation of new vaults.


## Functions
### vaults

Provides a list of all vaults created.


```solidity
function vaults() external view returns (address[] memory);
```

### vaultsForCollection

Provides a list of all vaults that reference the approved collection.


```solidity
function vaultsForCollection(address _collection) external view returns (address[] memory);
```

### vault

Provides a vault against the provided `vaultId` (index).


```solidity
function vault(uint _vaultId) external view returns (address);
```

### createVault

Creates a vault with an approved strategy and collection.


```solidity
function createVault(string memory _name, address _strategy, bytes memory _strategyInitData, address _collection)
    external
    returns (uint vaultId_, address vaultAddr_);
```

### pause


```solidity
function pause(uint _vaultId, bool _paused) external;
```

### migratePendingDeposits


```solidity
function migratePendingDeposits(uint _vaultId) external;
```

### distributeRewards


```solidity
function distributeRewards(uint _vaultId, uint _amount) external;
```

### claimRewards


```solidity
function claimRewards(uint _vaultId) external returns (uint);
```

### registerMint


```solidity
function registerMint(uint _vaultId, uint _amount) external;
```

## Events
### VaultCreated
*Sent when a vault is created successfully*


```solidity
event VaultCreated(uint indexed vaultId, address vaultAddress, address vaultXTokenAddress, address assetAddress);
```

### VaultCreationPaused
*Sent when a vault is paused or unpaused*


```solidity
event VaultCreationPaused(bool paused);
```

