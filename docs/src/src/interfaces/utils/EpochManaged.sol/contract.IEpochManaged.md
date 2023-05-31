# IEpochManaged
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/utils/EpochManaged.sol)


## Functions
### epochManager

Gets the address of the contract that currently manages the epoch state of
this contract.


```solidity
function epochManager() external returns (IEpochManager);
```

### setEpochManager

Allows the epoch manager to be updated.


```solidity
function setEpochManager(address _epochManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_epochManager`|`address`|The address of the new epoch manager|


