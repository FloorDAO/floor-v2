# AuthorityRegistry
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/authorities/AuthorityRegistry.sol)

**Inherits:**
Context, [IAuthorityRegistry](/src/interfaces/authorities/AuthorityRegistry.sol/contract.IAuthorityRegistry.md)

The {AuthorityRegistry} allows us to assign roles to wallet addresses that we can persist across
our various contracts. The roles will offer explicit permissions to perform actions within those
contracts.
Roles can be granted and revoked dynamically via the {grantRole} and {revokeRole} functions. Only
accounts that have an admin role can call {grantRole} and {revokeRole}.


## State Variables
### GOVERNOR
Explicit checks for admin roles required


```solidity
bytes32 public constant GOVERNOR = keccak256('Governor');
```


### GUARDIAN

```solidity
bytes32 public constant GUARDIAN = keccak256('Guardian');
```


### _roles
Role => Member => Access


```solidity
mapping(bytes32 => mapping(address => bool)) private _roles;
```


## Functions
### constructor

The address that deploys the {AuthorityRegistry} becomes the default controller.


```solidity
constructor();
```

### hasRole

Returns `true` if `account` has been granted `role`.


```solidity
function hasRole(bytes32 role, address account) public view virtual override returns (bool);
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
function hasAdminRole(address account) public view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to check ownership of role|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool If the address has the GOVERNOR or GUARDIAN role|


### grantRole

Grants `role` to `account`. If `account` had not been already granted `role`, emits
a {RoleGranted} event.
The caller _must_ have an admin role, otherwise the call will be reverted.
May emit a {RoleGranted} event.


```solidity
function grantRole(bytes32 role, address account) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The keccak256 encoded role string|
|`account`|`address`|Address to grant the role to|


### _grantRole

Handles the internal logic to grant an account a role, if they don't already hold
the role being granted.


```solidity
function _grantRole(bytes32 role, address account) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The keccak256 encoded role string|
|`account`|`address`|Address to grant the role to|


### revokeRole

Revokes `role` from `account`. If `account` had been granted `role`, emits a
{RoleRevoked} event.
The caller _must_ have an admin role, otherwise the call will be reverted.
May emit a {RoleRevoked} event.


```solidity
function revokeRole(bytes32 role, address account) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The keccak256 encoded role string|
|`account`|`address`|Address to revoke role from|


### renounceRole

Revokes `role` from the calling account.
Roles are often managed via {grantRole} and {revokeRole}: this function's
purpose is to provide a mechanism for accounts to lose their privileges
if they are compromised (such as when a trusted device is misplaced).
If the calling account had been revoked `role`, emits a {RoleRevoked}
event.
May emit a {RoleRevoked} event.

*The GOVERNOR role cannot be renounced.*


```solidity
function renounceRole(bytes32 role) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|The keccak256 encoded role string being revoked|


