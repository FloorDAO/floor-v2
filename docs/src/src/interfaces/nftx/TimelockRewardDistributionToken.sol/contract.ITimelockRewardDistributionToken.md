# ITimelockRewardDistributionToken
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/nftx/TimelockRewardDistributionToken.sol)


## Functions
### distributeRewards


```solidity
function distributeRewards(uint amount) external;
```

### mint


```solidity
function mint(address account, address to, uint amount) external;
```

### timelockMint


```solidity
function timelockMint(address account, uint amount, uint timelockLength) external;
```

### burnFrom


```solidity
function burnFrom(address account, uint amount) external;
```

### withdrawReward


```solidity
function withdrawReward(address user) external;
```

### dividendOf


```solidity
function dividendOf(address _owner) external view returns (uint);
```

### withdrawnRewardOf


```solidity
function withdrawnRewardOf(address _owner) external view returns (uint);
```

### accumulativeRewardOf


```solidity
function accumulativeRewardOf(address _owner) external view returns (uint);
```

### timelockUntil


```solidity
function timelockUntil(address account) external view returns (uint);
```

