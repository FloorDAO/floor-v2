# BoostStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/staking/BoostStaking.sol)

**Inherits:**
[IBoostStaking](/src/interfaces/staking/BoostStaking.sol/contract.IBoostStaking.md), Pausable

This contract allows a specified NFT to be depoited into it to generate additional
vote reward boosting. When designing this we wanted to keep the reward gain non-linear,
so that it wasn't about hoarding NFTs but instead about pooling a small number of
higher boost value NFTs together.
To achieve this, we use a formula that effectively increases the degredation based on
a numerical index against the total number of staked NFTs:
```
10% + 5% + 5% = (10 / sqrt(1)) + (5 / sqrt(2)) + (5 / sqrt(3)) = 16.422
10% + 10% = (10 / sqrt(1)) + (10 / sqrt(2))
```
We prioritise higher level boost values, so after a number of staked items come in,
gains will be negligible.


## State Variables
### RARITIES
Representation of rarity boost values to 1 decimal accuracy


```solidity
uint8[4] internal RARITIES = [10, 25, 50, 100];
```


### tokenStaked
Returns the address of the user that has staked the specified `tokenId`.


```solidity
mapping(uint => address) public tokenStaked;
```


### userTokens
Gets the number tokens that a user has staked at each boost value.


```solidity
mapping(address => mapping(uint8 => uint16)) public userTokens;
```


### boosts
The boost value applied to the user.


```solidity
mapping(address => uint) public boosts;
```


### nft
NFT contract address.


```solidity
address public immutable nft;
```


### tokenStore
The external NFT meta data store contract


```solidity
ISweeperMetadataStore public immutable tokenStore;
```


## Functions
### constructor

Sets up our immutable contract addresses.


```solidity
constructor(address _nft, address _tokenStore);
```

### stake

Stakes an approved NFT into the contract and provides a boost based on the relevant
metadata on the NFT.

*This can only be called when the contract is not paused.*


```solidity
function stake(uint _tokenId) external updateRewards whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Token ID to be staked|


### unstake

Unstakes an approved NFT from the contract and reduced the user's boost based on
the relevant metadata on the NFT.


```solidity
function unstake(uint _tokenId) external updateRewards;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|Token ID to be staked|


### updateRewards

After a transaction is run, this logic will recalculate the user's boosted balance based
on an a degrading curve outlined at the top of this contract.


```solidity
modifier updateRewards();
```

