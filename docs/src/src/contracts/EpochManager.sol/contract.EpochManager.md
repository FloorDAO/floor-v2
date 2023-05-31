# EpochManager
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/EpochManager.sol)

**Inherits:**
[IEpochManager](/src/interfaces/EpochManager.sol/contract.IEpochManager.md), Ownable

Handles epoch management for all other contracts.


## State Variables
### currentEpoch
Stores the current epoch that is taking place.


```solidity
uint public currentEpoch;
```


### lastEpoch
Store a timestamp of when last epoch was run so that we can timelock usage


```solidity
uint public lastEpoch;
```


### EPOCH_LENGTH
Store the length of an epoch


```solidity
uint public constant EPOCH_LENGTH = 7 days;
```


### newCollectionWars
Holds our internal contract references


```solidity
INewCollectionWars public newCollectionWars;
```


### voteMarket

```solidity
IVoteMarket public voteMarket;
```


### collectionEpochs
Stores a mapping of an epoch to a collection


```solidity
mapping(uint => uint) public collectionEpochs;
```


### epochEndTriggers
Store our epoch triggers


```solidity
address[] public epochEndTriggers;
```


## Functions
### setCurrentEpoch

Allows a new epoch to be set. This should, in theory, only be set to one
above the existing `currentEpoch`.


```solidity
function setCurrentEpoch(uint _currentEpoch) external onlyOwner;
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
|`<none>`|`bool`|bool If the current epoch is a collection addition|


### isCollectionAdditionEpoch

Will return true if the specified epoch is a collection addition vote.


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
|`<none>`|`bool`|bool If the specified epoch is a collection addition|


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
If the epoch has successfully ended, then the `currentEpoch` value will be increased
by one, and the epoch will be locked from updating again until `EPOCH_LENGTH` has
passed. We will also check if a new Collection Addition is starting in the new epoch
and initialise it if it is.


```solidity
function endEpoch() external;
```

### setEpochEndTrigger

Allows a new epochEnd trigger to be attached


```solidity
function setEpochEndTrigger(address contractAddr, bool enabled) external onlyOwner;
```

### epochIterationTimestamp

Provides an estimated timestamp of when an epoch started, and also the earliest
that an epoch in the future could start.


```solidity
function epochIterationTimestamp(uint _epoch) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epoch`|`uint256`|The epoch to find the estimated timestamp of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The estimated timestamp of when the specified epoch started|


### setContracts

Sets the contract addresses of internal contracts that are queried and used
in other functions.


```solidity
function setContracts(address _newCollectionWars, address _voteMarket) external onlyOwner;
```

