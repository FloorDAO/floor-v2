# IEpochManaged
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/utils/EpochManaged.sol)


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


