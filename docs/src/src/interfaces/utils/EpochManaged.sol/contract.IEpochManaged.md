# IEpochManaged
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/utils/EpochManaged.sol)


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


