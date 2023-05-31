# NftStakingLocker
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/staking/strategies/NftStakingLocker.sol)

**Inherits:**
[INftStakingStrategy](/src/interfaces/staking/strategies/NftStakingStrategy.sol/contract.INftStakingStrategy.md), Ownable

This contract allows approved collection NFTs to be depoited into it to generate
additional vote reward boosting through the calculation of a multiplier.
Unlike other staking strategies, this simply locks them without external
interaction. This means that it generates no yield or benefit other that vote
locking.


## State Variables
### nftStaking
Our {NftStakingStrategy} contract that will be used for staked tokens


```solidity
address internal immutable nftStaking;
```


### tokenIds
Map collection => user => boolean


```solidity
mapping(address => mapping(address => uint[])) public tokenIds;
```


### tokenAmounts

```solidity
mapping(address => mapping(address => uint[])) public tokenAmounts;
```


### underlyingTokenMapping
Stores the equivalent ERC20 of the ERC721


```solidity
mapping(address => address) public underlyingTokenMapping;
```


## Functions
### constructor

Sets up our immutable contract addresses.


```solidity
constructor(address _nftStaking);
```

### approvalAddress

Shows the address that should be approved by a staking user.


```solidity
function approvalAddress() external view returns (address);
```

### stake

Stakes an approved collection NFT into the contract and provides a boost based on
the price of the underlying ERC20.

*This can only be called when the contract is not paused.*


```solidity
function stake(address _user, address _collection, uint[] calldata _tokenId, uint[] calldata _amount, bool _is1155)
    external
    onlyNftStaking;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|Address of the user staking their tokens|
|`_collection`|`address`|Approved collection contract|
|`_tokenId`|`uint256[]`||
|`_amount`|`uint256[]`||
|`_is1155`|`bool`|If the collection is an ERC1155 standard|


### unstake

Unstakes an approved NFT from the contract and reduced the user's boost based on
the relevant metadata on the NFT.


```solidity
function unstake(address recipient, address _collection, uint numNfts, uint, uint remainingPortionToUnstake, bool _is1155)
    external
    onlyNftStaking;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the unstaked NFT|
|`_collection`|`address`|The collection to unstake|
|`numNfts`|`uint256`|The number of NFTs to unstake|
|`<none>`|`uint256`||
|`remainingPortionToUnstake`|`uint256`|The dust of NFT to unstake|
|`_is1155`|`bool`|If the collection matches the EIP-1155 standard|


### rewardsAvailable

We don't have any rewards as we only deposit and withdraw a 1:1 mapping
of tokens and their amounts. No rewards are generated.


```solidity
function rewardsAvailable(address) external pure returns (uint);
```

### claimRewards

We don't have any rewards as we only deposit and withdraw a 1:1 mapping
of tokens and their amounts. No rewards are generated.


```solidity
function claimRewards(address) external pure returns (uint);
```

### underlyingToken

Gets the underlying token for a collection.


```solidity
function underlyingToken(address _collection) external view returns (address);
```

### setUnderlyingToken

Maps a collection address to an underlying NFTX token address. This will allow us to generate
a price calculation against the collection


```solidity
function setUnderlyingToken(address _collection, address _token, address) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|Our approved collection address|
|`_token`|`address`|The underlying token (the NFTX vault contract address)|
|`<none>`|`address`||


### onERC721Received

Allows the contract to receive ERC721 tokens.


```solidity
function onERC721Received(address, address, uint, bytes memory) public virtual returns (bytes4);
```

### onERC1155Received

Allows the contract to receive ERC1155 tokens.


```solidity
function onERC1155Received(address, address, uint, uint, bytes calldata) public virtual returns (bytes4);
```

### onERC1155BatchReceived

Allows the contract to receive batch ERC1155 tokens.


```solidity
function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4);
```

### onlyNftStaking

Ensures that only the {NftStaking} contract can call the function.


```solidity
modifier onlyNftStaking();
```

