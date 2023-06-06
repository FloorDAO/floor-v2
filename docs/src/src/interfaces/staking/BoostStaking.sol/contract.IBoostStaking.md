# IBoostStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/staking/BoostStaking.sol)


## Functions
### tokenStaked

Returns the address of the user that has staked the specified `tokenId`.


```solidity
function tokenStaked(uint) external returns (address);
```

### userTokens

Gets the number tokens that a user has staked at each boost value.


```solidity
function userTokens(address, uint8) external returns (uint16);
```

### boosts

The boost value applied to the user.


```solidity
function boosts(address) external returns (uint);
```

### nft

NFT contract address.


```solidity
function nft() external returns (address);
```

### stake

Stakes an approved NFT into the contract and provides a boost based on the relevant
metadata on the NFT.

*This can only be called when the contract is not paused.*


```solidity
function stake(uint _tokenId) external;
```

### unstake

Unstakes an approved NFT from the contract and reduced the user's boost based on
the relevant metadata on the NFT.


```solidity
function unstake(uint _tokenId) external;
```

## Events
### Staked
Emitted when an NFT is staked


```solidity
event Staked(uint tokenId);
```

### Unstaked
Emitted when an NFT is unstaked


```solidity
event Unstaked(uint tokenId);
```

