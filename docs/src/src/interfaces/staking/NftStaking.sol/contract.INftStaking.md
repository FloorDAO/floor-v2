# INftStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/interfaces/staking/NftStaking.sol)


## Functions
### collectionStakerIndex


```solidity
function collectionStakerIndex(bytes32) external returns (uint);
```

### voteDiscount


```solidity
function voteDiscount() external returns (uint16);
```

### sweepModifier


```solidity
function sweepModifier() external returns (uint64);
```

### collectionBoost


```solidity
function collectionBoost(address _collection) external view returns (uint boost_);
```

### collectionBoost


```solidity
function collectionBoost(address _collection, uint _epoch) external view returns (uint boost_);
```

### stake


```solidity
function stake(address _collection, uint[] calldata _tokenId, uint[] calldata _amount, uint8 _epochCount, bool _is1155) external;
```

### unstake


```solidity
function unstake(address _collection, bool _is1155) external;
```

### unstake


```solidity
function unstake(address _collection, address _nftStakingStrategy, bool _is1155) external;
```

### unstakeFees


```solidity
function unstakeFees(address _collection) external returns (uint);
```

### setVoteDiscount


```solidity
function setVoteDiscount(uint16 _voteDiscount) external;
```

### setSweepModifier


```solidity
function setSweepModifier(uint64 _sweepModifier) external;
```

### setPricingExecutor


```solidity
function setPricingExecutor(address _pricingExecutor) external;
```

### setBoostCalculator


```solidity
function setBoostCalculator(address _boostCalculator) external;
```

### claimRewards


```solidity
function claimRewards(address _collection) external;
```

## Events
### TokensStaked
Emitted when a token is staked


```solidity
event TokensStaked(address sender, uint tokens, uint tokenValue, uint currentEpoch, uint8 epochCount);
```

### TokensUnstaked
Emitted when a token is unstaked


```solidity
event TokensUnstaked(address sender, uint numNfts, uint remainingPortionToUnstake, uint fees);
```

