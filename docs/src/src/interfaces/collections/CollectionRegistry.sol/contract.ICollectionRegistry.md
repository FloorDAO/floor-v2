# ICollectionRegistry
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/collections/CollectionRegistry.sol)

Allows collection contracts to be approved and revoked by addresses holding the
{CollectionManager} role. Only once approved can these collections be applied to
new or existing vaults. They will only need to be stored as a mapping of address
to boolean.


## Functions
### isApproved

Returns `true` if the contract address is an approved collection, otherwise
returns `false`.


```solidity
function isApproved(address contractAddr) external view returns (bool);
```

### approvedCollections

Returns an array of all approved collections.


```solidity
function approvedCollections() external view returns (address[] memory);
```

### approveCollection

Approves a collection contract to be used for vaults.


```solidity
function approveCollection(address contractAddr, address underlyingToken) external;
```

## Events
### CollectionApproved
Emitted when a collection is successfully approved


```solidity
event CollectionApproved(address contractAddr);
```

### CollectionRevoked
Emitted when a collection has been successfully revoked


```solidity
event CollectionRevoked(address contractAddr);
```

