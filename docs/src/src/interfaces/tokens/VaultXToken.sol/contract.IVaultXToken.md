# IVaultXToken
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/tokens/VaultXToken.sol)


## Functions
### mint


```solidity
function mint(address account, uint amount) external;
```

### burnFrom


```solidity
function burnFrom(address account, uint amount) external;
```

### distributeRewards


```solidity
function distributeRewards(uint amount) external;
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

## Events
### RewardsDistributed
*This event MUST emit when target is distributed to token holders.*


```solidity
event RewardsDistributed(address indexed from, uint weiAmount);
```

### RewardWithdrawn
*This event MUST emit when an address withdraws their dividend.*


```solidity
event RewardWithdrawn(address indexed to, uint weiAmount);
```

