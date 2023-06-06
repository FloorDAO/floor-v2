# INftStakingStrategy
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/interfaces/staking/strategies/NftStakingStrategy.sol)


## Functions
### approvalAddress


```solidity
function approvalAddress() external view returns (address);
```

### stake


```solidity
function stake(address _user, address _collection, uint[] calldata _tokenId, uint[] calldata _amounts, bool _is1155) external;
```

### unstake


```solidity
function unstake(address recipient, address _collection, uint numNfts, uint baseNfts, uint remainingPortionToUnstake, bool _is1155)
    external;
```

### rewardsAvailable


```solidity
function rewardsAvailable(address _collection) external returns (uint);
```

### claimRewards


```solidity
function claimRewards(address _collection) external returns (uint);
```

### underlyingToken


```solidity
function underlyingToken(address _collection) external view returns (address);
```

### setUnderlyingToken


```solidity
function setUnderlyingToken(address _collection, address _token, address _xToken) external;
```

### onERC721Received


```solidity
function onERC721Received(address, address, uint, bytes memory) external returns (bytes4);
```

