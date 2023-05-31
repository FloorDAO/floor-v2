# INFTXLiquidityStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/nftx/NFTXLiquidityStaking.sol)


## Functions
### nftxVaultFactory


```solidity
function nftxVaultFactory() external view returns (address);
```

### rewardDistTokenImpl


```solidity
function rewardDistTokenImpl() external view returns (address);
```

### stakingTokenProvider


```solidity
function stakingTokenProvider() external view returns (address);
```

### vaultToken


```solidity
function vaultToken(address _stakingToken) external view returns (address);
```

### stakingToken


```solidity
function stakingToken(address _vaultToken) external view returns (address);
```

### rewardDistributionToken


```solidity
function rewardDistributionToken(uint vaultId) external view returns (address);
```

### newRewardDistributionToken


```solidity
function newRewardDistributionToken(uint vaultId) external view returns (address);
```

### oldRewardDistributionToken


```solidity
function oldRewardDistributionToken(uint vaultId) external view returns (address);
```

### unusedRewardDistributionToken


```solidity
function unusedRewardDistributionToken(uint vaultId) external view returns (address);
```

### rewardDistributionTokenAddr


```solidity
function rewardDistributionTokenAddr(address stakedToken, address rewardToken) external view returns (address);
```

### receiveRewards


```solidity
function receiveRewards(uint vaultId, uint amount) external returns (bool);
```

### deposit


```solidity
function deposit(uint vaultId, uint amount) external;
```

### timelockDepositFor


```solidity
function timelockDepositFor(uint vaultId, address account, uint amount, uint timelockLength) external;
```

### exit


```solidity
function exit(uint vaultId, uint amount) external;
```

### rescue


```solidity
function rescue(uint vaultId) external;
```

### withdraw


```solidity
function withdraw(uint vaultId, uint amount) external;
```

### claimRewards


```solidity
function claimRewards(uint vaultId) external;
```

