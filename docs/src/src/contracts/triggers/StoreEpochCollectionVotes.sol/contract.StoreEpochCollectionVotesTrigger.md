# StoreEpochCollectionVotesTrigger
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/triggers/StoreEpochCollectionVotes.sol)

**Inherits:**
[EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), [IEpochEndTriggered](/src/interfaces/utils/EpochEndTriggered.sol/contract.IEpochEndTriggered.md)

When an epoch ends, this contract maintains an indexed list of all collections that
were a part of it and the respective vote power attached to each.


## State Variables
### sweepWars
The sweep war contract used by this contract


```solidity
ISweepWars public immutable sweepWars;
```


### epochSnapshots
Store a mapping of epoch to snapshot results


```solidity
mapping(uint => EpochSnapshot) internal epochSnapshots;
```


## Functions
### constructor

Sets our internal contracts.


```solidity
constructor(address _sweepWars);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sweepWars`|`address`|The {SweepWars} contract being referenced|


### endEpoch

When the epoch ends, we capture the collections that took part and their respective
votes. This is then stored in our mapped structure.


```solidity
function endEpoch(uint epoch) external onlyEpochManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The epoch that is ending|


### epochSnapshot

Public function to get epoch snapshot data.


```solidity
function epochSnapshot(uint epoch) external view returns (address[] memory, int[] memory);
```

## Structs
### EpochSnapshot
Holds the data for each epoch to show collections and their votes.

*The epoch `uint` is required otherwise Solidity breaks as required non-array.*


```solidity
struct EpochSnapshot {
    uint epoch;
    address[] collections;
    int[] votes;
}
```

