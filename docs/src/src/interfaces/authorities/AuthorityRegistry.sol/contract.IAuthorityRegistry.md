# IAuthorityRegistry
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/authorities/AuthorityRegistry.sol)

This interface expands upon the OpenZeppelin `IAccessControl` interface:
https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/access/IAccessControl.sol


## Functions
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

### grantRole

*Grants `role` to `account`.
If `account` had not been already granted `role`, emits a {RoleGranted}
event.
Requirements:
- the caller must have ``role``'s admin role.*


```solidity
function grantRole(bytes32 role, address account) external;
```

### revokeRole

*Revokes `role` from `account`.
If `account` had been granted `role`, emits a {RoleRevoked} event.
Requirements:
- the caller must have ``role``'s admin role.*


```solidity
function revokeRole(bytes32 role, address account) external;
```

### renounceRole

*Revokes `role` from the calling account.
Roles are often managed via {grantRole} and {revokeRole}: this function's
purpose is to provide a mechanism for accounts to lose their privileges
if they are compromised (such as when a trusted device is misplaced).
If the calling account had been granted `role`, emits a {RoleRevoked}
event.
Requirements:
- the caller must be `account`.*


```solidity
function renounceRole(bytes32 role) external;
```

## Events
### RoleGranted
*Emitted when `account` is granted `role`.
`sender` is the account that originated the contract call, an admin role
bearer except when using {AccessControl-_setupRole}.*


```solidity
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
```

### RoleRevoked
*Emitted when `account` is revoked `role`.
`sender` is the account that originated the contract call:
- if using `revokeRole`, it is the admin role bearer
- if using `renounceRole`, it is the role bearer (i.e. `account`)*


```solidity
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
```

