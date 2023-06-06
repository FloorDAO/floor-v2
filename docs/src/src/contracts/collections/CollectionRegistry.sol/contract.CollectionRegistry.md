# CollectionRegistry
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/collections/CollectionRegistry.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [ICollectionRegistry](/src/interfaces/collections/CollectionRegistry.sol/contract.ICollectionRegistry.md)

Allows collection contracts to be approved and revoked by addresses holding the
{CollectionManager} role. Only once approved can these collections be applied to
new or existing vaults. They will only need to be stored as a mapping of address
to boolean.


## State Variables
### collections
Store a mapping of our approved collections


```solidity
mapping(address => bool) internal collections;
```


### _approvedCollections
Maintains an internal array of approved collections for iteration


```solidity
address[] internal _approvedCollections;
```


### pricingExecutor
Store our pricing executor to validate liquidity before collection addition


```solidity
IBasePricingExecutor public pricingExecutor;
```


### liquidityThreshold
Stores a minimum liquidity threshold that is enforced before a collection can
be approved.


```solidity
uint public liquidityThreshold;
```


## Functions
### constructor

Sets up our contract with our authority control to restrict access to
protected functions.


```solidity
constructor(address _authority) AuthorityControl(_authority);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_authority`|`address`|{AuthorityRegistry} contract address|


### isApproved

Checks if a collection has previously been approved.


```solidity
function isApproved(address contractAddr) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddr`|`address`|The collection address to be checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Returns `true` if the contract address is an approved collection, otherwise returns `false`.|


### approvedCollections

Returns an array of collection addresses that have been approved.


```solidity
function approvedCollections() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|address[] Array of collection addresses|


### approveCollection

Approves a collection contract to be used for vaults.
The collection address cannot be null, and if it is already approved then no changes
will be made.
The caller must have the `COLLECTION_MANAGER` role.


```solidity
function approveCollection(address contractAddr, address underlyingToken) external onlyRole(COLLECTION_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddr`|`address`|Address of unapproved collection to approve|
|`underlyingToken`|`address`||


### unapproveCollection

Unapproves a collection contract to be used for vaults.
This will prevent the collection from being used in any future strategies.
The caller must have the `COLLECTION_MANAGER` role.


```solidity
function unapproveCollection(address contractAddr) external onlyRole(COLLECTION_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddr`|`address`|Address of approved collection to unapprove|


### setPricingExecutor

Sets our {PricingExecutor} contract address.


```solidity
function setPricingExecutor(address _pricingExecutor) external onlyRole(COLLECTION_MANAGER);
```

### setCollectionLiquidityThreshold

Sets our collection liqudity threshold value.


```solidity
function setCollectionLiquidityThreshold(uint _liquidityThreshold) external onlyRole(COLLECTION_MANAGER);
```

