# EpochManaged
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/utils/EpochManaged.sol)

**Inherits:**
Ownable


## State Variables
### epochManager
Stores the current {EpochManager} contract


```solidity
IEpochManager public epochManager;
```


## Functions
### setEpochManager

Allows an updated {EpochManager} address to be set.


```solidity
function setEpochManager(address _epochManager) external virtual onlyOwner;
```

### currentEpoch

Gets the current epoch from our {EpochManager}.


```solidity
function currentEpoch() internal view virtual returns (uint);
```

### onlyEpochManager

Checks that the contract caller is the {EpochManager}.


```solidity
modifier onlyEpochManager();
```

