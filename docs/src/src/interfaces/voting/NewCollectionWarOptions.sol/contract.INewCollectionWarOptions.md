# INewCollectionWarOptions
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/voting/NewCollectionWarOptions.sol)


## Functions
### createOption


```solidity
function createOption(uint war, address collection, uint[] calldata tokenIds, uint40[] calldata amounts, uint56[] calldata exercisePercents)
    external;
```

### reclaimOptions


```solidity
function reclaimOptions(uint war, address collection, uint56[] calldata exercisePercents, uint[][] calldata indexes) external;
```

### exerciseOptions


```solidity
function exerciseOptions(uint war, uint amount) external payable;
```

### nftVotingPower


```solidity
function nftVotingPower(uint war, address collection, uint spotPrice, uint exercisePercent) external view returns (uint);
```

## Events
### CollectionExercised
Sent when Collection Addition War NFTs are exercised


```solidity
event CollectionExercised(uint warIndex, address collection, uint value);
```

## Structs
### Option
Stores information about a user's option.


```solidity
struct Option {
    uint tokenId;
    address user;
    uint96 amount;
}
```

### StakedCollectionERC721
Stores information about the NFT that has been staked. This allows either
the DAO to exercise the NFT, or for the initial staker to reclaim it.


```solidity
struct StakedCollectionERC721 {
    address staker;
    uint56 exercisePercent;
}
```

### StakedCollectionERC1155

```solidity
struct StakedCollectionERC1155 {
    address staker;
    uint56 exercisePercent;
    uint40 amount;
}
```

