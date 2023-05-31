# AuthorityControl
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/authorities/AuthorityControl.sol)

**Inherits:**
Context, [IAuthorityControl](/src/interfaces/authorities/AuthorityControl.sol/contract.IAuthorityControl.md)

This contract is heavily based on the standardised OpenZeppelin `AccessControl` library.
This allows for the creation of role based access levels that can be assigned to 1-n
addresses.
Contracts will be able to implement the AuthorityControl to provide access to the `onlyRole` modifier or the
`hasRole` function. This will ensure that the `msg.sender` has is allowed to perform an action.
Roles are referred to by their `bytes32` identifier. These should be exposed in the external API and be
unique. The best way to achieve this is by using `public constant` hash digests:
```
bytes32 public constant MY_ROLE = keccak256("TreasuryManager");
```


## State Variables
### COLLECTION_MANAGER
CollectionManager - Can approve token addresses to be allowed to be used in vaults


```solidity
bytes32 public constant COLLECTION_MANAGER = keccak256('CollectionManager');
```


### FLOOR_MANAGER
FloorManager - Can mint and manage Floor and VeFloor tokens


```solidity
bytes32 public constant FLOOR_MANAGER = keccak256('FloorManager');
```


### GOVERNOR
Governor - A likely DAO owned vote address to allow for wide scale decisions to
be made and implemented.


```solidity
bytes32 public constant GOVERNOR = keccak256('Governor');
```


### GUARDIAN
Guardian - Wallet address that will allow for Governor based actions, except without
timeframe restrictions.


```solidity
bytes32 public constant GUARDIAN = keccak256('Guardian');
```


### TREASURY_MANAGER
TreasuryManager - Access to Treasury asset management


```solidity
bytes32 public constant TREASURY_MANAGER = keccak256('TreasuryManager');
```


### VAULT_MANAGER
VaultManager - Can create new vaults against approved strategies and collections


```solidity
bytes32 public constant VAULT_MANAGER = keccak256('VaultManager');
```


### VOTE_MANAGER
VoteManager - Can manage account votes


```solidity
bytes32 public constant VOTE_MANAGER = keccak256('VoteManager');
```


### registry
Reference to the {AuthorityRegistry} contract that maintains role allocations


```solidity
IAuthorityRegistry public immutable registry;
```


## Functions
### onlyRole

Modifier that checks that an account has a specific role. Reverts with a
standardized message if user does not have specified role.


```solidity
modifier onlyRole(bytes32 role);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The keccak256 encoded role string|


### onlyAdminRole

Modifier that checks that an account has a governor or guardian role.
Reverts with a standardized message if sender does not have an admin role.


```solidity
modifier onlyAdminRole();
```

### constructor

The address that deploys the {AuthorityControl} becomes the default controller. This
can only be overwritten by the existing.


```solidity
constructor(address _registry);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_registry`|`address`|The address of our deployed AuthorityRegistry contract|


### hasRole

Returns `true` if `account` has been granted `role`.


```solidity
function hasRole(bytes32 role, address account) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The keccak256 encoded role string|
|`account`|`address`|Address to check ownership of role|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool If the address has the specified user role|


### hasAdminRole

Returns `true` if `account` has been granted either GOVERNOR or GUARDIAN role.


```solidity
function hasAdminRole(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check ownership of role|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool If the address has the GOVERNOR or GUARDIAN role|


