# ITimelockRewardDistributionToken
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/nftx/TimelockRewardDistributionToken.sol)


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

