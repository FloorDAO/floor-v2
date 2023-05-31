# IEpochManager
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/EpochManager.sol)

Handles epoch management for all other contracts.


## Functions
### currentEpoch

The current epoch that is running across the codebase.


```solidity
function currentEpoch() external view returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current epoch|


### collectionEpochs

Stores a mapping of an epoch to a collection addition war index.


```solidity
function collectionEpochs(uint _epoch) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epoch`|`uint256`|Epoch to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Index of the collection addition war. Will return 0 if none found|


### setCurrentEpoch

Allows a new epoch to be set. This should, in theory, only be set to one
above the existing `currentEpoch`.


```solidity
function setCurrentEpoch(uint _currentEpoch) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_currentEpoch`|`uint256`|The new epoch to set|


### isCollectionAdditionEpoch

Will return if the current epoch is a collection addition vote.


```solidity
function isCollectionAdditionEpoch() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|If the current epoch is a collection addition|


### isCollectionAdditionEpoch

Will return if the specified epoch is a collection addition vote.


```solidity
function isCollectionAdditionEpoch(uint epoch) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The epoch to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|If the specified epoch is a collection addition|


### scheduleCollectionAddtionEpoch

Allows an epoch to be scheduled to be a collection addition vote. An index will
be specified to show which collection addition will be used. The index will not
be a zero value.


```solidity
function scheduleCollectionAddtionEpoch(uint epoch, uint index) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The epoch that the Collection Addition will take place in|
|`index`|`uint256`|The Collection Addition array index|


### endEpoch

Triggers an epoch to end.

*More information about this function can be found in the actual contract*


```solidity
function endEpoch() external;
```

### epochIterationTimestamp

Provides an estimated timestamp of when an epoch started, and also the earliest
that an epoch in the future could start.


```solidity
function epochIterationTimestamp(uint _epoch) external returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epoch`|`uint256`|The epoch to find the estimated timestamp of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The estimated timestamp of when the specified epoch started|


### EPOCH_LENGTH

The length of an epoch in seconds.


```solidity
function EPOCH_LENGTH() external returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The length of the epoch in seconds|


### setContracts

Sets contracts that the epoch manager relies on. This doesn't have to include
all of the contracts that are {EpochManaged}, but only needs to set ones that the
{EpochManager} needs to interact with.


```solidity
function setContracts(address _newCollectionWars, address _voteMarket) external;
```

## Events
### EpochEnded

```solidity
event EpochEnded(uint epoch, uint timestamp);
```

### CollectionAdditionWarScheduled

```solidity
event CollectionAdditionWarScheduled(uint epoch, uint index);
```

