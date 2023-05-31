# IAuthorityControl
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/authorities/AuthorityControl.sol)


## Functions
### COLLECTION_MANAGER

CollectionManager - Can approve token addresses to be allowed to be used in vaults


```solidity
function COLLECTION_MANAGER() external returns (bytes32);
```

### FLOOR_MANAGER

FloorManager - Can mint and manage Floor and VeFloor tokens


```solidity
function FLOOR_MANAGER() external returns (bytes32);
```

### GOVERNOR

Governor - A likely DAO owned vote address to allow for wide scale decisions to
be made and implemented.


```solidity
function GOVERNOR() external returns (bytes32);
```

### GUARDIAN

Guardian - Wallet address that will allow for Governor based actions, except without
timeframe restrictions.


```solidity
function GUARDIAN() external returns (bytes32);
```

### TREASURY_MANAGER

TreasuryManager - Access to Treasury asset management


```solidity
function TREASURY_MANAGER() external returns (bytes32);
```

### VAULT_MANAGER

VaultManager - Can create new vaults against approved strategies and collections


```solidity
function VAULT_MANAGER() external returns (bytes32);
```

### VOTE_MANAGER

VoteManager - Can manage account votes


```solidity
function VOTE_MANAGER() external returns (bytes32);
```

### hasRole

*Returns `true` if `account` has been granted `role`.*


```solidity
function hasRole(bytes32 role, address account) external view returns (bool);
```

### hasAdminRole

*Returns `true` if `account` has been granted either the GOVERNOR or
GUARDIAN `role`.*


```solidity
function hasAdminRole(address account) external view returns (bool);
```

