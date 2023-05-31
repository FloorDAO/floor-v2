# NftStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/staking/NftStaking.sol)

**Inherits:**
[EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), [INftStaking](/src/interfaces/staking/NftStaking.sol/contract.INftStaking.md), Pausable

This contract allows approved collection NFTs to be depoited into it to generate
additional vote reward boosting through the calculation of a multiplier.


## State Variables
### nftStakingStrategy
Stores our modular NFT staking strategy.

*When tokens are approved to be staked, it should call the `approvalAddress`
on this contract to show the address to be approved.*


```solidity
INftStakingStrategy public nftStakingStrategy;
```


### previousStrategies
Stores a list of all strategies that have been used


```solidity
address[] public previousStrategies;
```


### stakedNfts
Stores the boosted number of votes available to a user


```solidity
mapping(bytes32 => StakedNft) public stakedNfts;
```


### collectionStakers
Stores an array of collections the user has currently staked NFTs for


```solidity
mapping(bytes32 => address[]) internal collectionStakers;
```


### collectionStakerIndex

```solidity
mapping(bytes32 => uint) public collectionStakerIndex;
```


### voteDiscount
Store the amount of discount applied to voting power of staked NFT


```solidity
uint16 public voteDiscount;
```


### sweepModifier

```solidity
uint64 public sweepModifier;
```


### pricingExecutor
Store our pricing executor that will determine the vote power of our NFT


```solidity
IBasePricingExecutor public pricingExecutor;
```


### boostCalculator
Store our boost calculator contract that will calculate our modifier


```solidity
INftStakingBoostCalculator public boostCalculator;
```


### waiveUnstakeFees

```solidity
mapping(address => bool) public waiveUnstakeFees;
```


### LOCK_PERIODS
Set a list of locking periods that the user can lock for


```solidity
uint8[] public LOCK_PERIODS = [uint8(0), 4, 13, 26, 52, 78, 104];
```


## Functions
### constructor

Sets up our immutable contract addresses.


```solidity
constructor(address _pricingExecutor, uint16 _voteDiscount);
```

### collectionBoost

Gets the total boost value for collection, based on the amount of NFTs that have been
staked, as well as the value and duration at which they staked at.


```solidity
function collectionBoost(address _collection) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The address of the collection we are checking the boost multiplier of|


### collectionBoost

Gets the total boost value for collection, based on the amount of NFTs that have been
staked, as well as the value and duration at which they staked at.


```solidity
function collectionBoost(address _collection, uint _epoch) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The address of the collection we are checking the boost multiplier of|
|`_epoch`|`uint256`|The epoch to get the value at|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The boost multiplier for the collection to 9 decimal places|


### _calculateStakePower


```solidity
function _calculateStakePower(address _user, address _collection, uint cachedFloorPrice, uint currentEpoch, uint targetEpoch)
    internal
    view
    returns (uint sweepPower, uint sweepTotal);
```

### stake

Stakes an approved collection NFT into the contract and provides a boost based on
the price of the underlying ERC20.

*This can only be called when the contract is not paused.*


```solidity
function stake(address _collection, uint[] calldata _tokenId, uint[] calldata _amount, uint8 _epochCount, bool _is1155)
    external
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|Approved collection contract|
|`_tokenId`|`uint256[]`||
|`_amount`|`uint256[]`||
|`_epochCount`|`uint8`|The number of epochs to stake for|
|`_is1155`|`bool`||


### unstake

Unstakes an approved NFT from the contract and reduced the user's boost based on
the relevant metadata on the NFT.


```solidity
function unstake(address _collection, bool _is1155) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The collection to unstake|
|`_is1155`|`bool`||


### unstake


```solidity
function unstake(address _collection, address _nftStakingStrategy, bool _is1155) external;
```

### _unstake


```solidity
function _unstake(address _collection, address _nftStakingStrategy, bool _is1155) internal;
```

### unstakeFees

Calculates the amount in fees it would cost the calling user to unstake.


```solidity
function unstakeFees(address _collection) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The collection being unstaked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount in fees to unstake|


### _unstakeFees

Calculates the amount in fees for a specific address to unstake from a collection.


```solidity
function _unstakeFees(address _strategy, address _collection, address _sender) internal view returns (uint fees);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_strategy`|`address`||
|`_collection`|`address`|The collection being unstaked|
|`_sender`|`address`|The caller that is unstaking|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fees`|`uint256`|The amount in fees to unstake|


### claimRewards

Allows rewards to be claimed from the staked NFT inventory positions.


```solidity
function claimRewards(address _collection) external;
```

### setVoteDiscount

Set our Vote Discount value to increase or decrease the amount of base value that
an NFT has.

*The value is passed to 2 decimal place accuracy*


```solidity
function setVoteDiscount(uint16 _voteDiscount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_voteDiscount`|`uint16`|The amount of vote discount to apply|


### setSweepModifier

In addition to the {setVoteDiscount} function, our sweep modifier allows us to
modify our resulting modifier calculation. A higher value will reduced the output
modifier, whilst reducing the value will increase it.


```solidity
function setSweepModifier(uint64 _sweepModifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sweepModifier`|`uint64`|The amount to modify our multiplier|


### setPricingExecutor

Sets an updated pricing executor (needs to confirm an implementation function).


```solidity
function setPricingExecutor(address _pricingExecutor) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pricingExecutor`|`address`|Address of new {IBasePricingExecutor} contract|


### setWaiveUnstakeFees

Allows the contract to waive early unstaking fees.


```solidity
function setWaiveUnstakeFees(address _strategy, bool _waiveUnstakeFees) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_strategy`|`address`||
|`_waiveUnstakeFees`|`bool`|New value|


### setBoostCalculator

Allows a new boost calculator to be set.


```solidity
function setBoostCalculator(address _boostCalculator) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_boostCalculator`|`address`|The new boost calculator contract address|


### setStakingStrategy

Allows our staking strategy to be updated.


```solidity
function setStakingStrategy(address _nftStakingStrategy) external onlyOwner;
```

### hash

Creates a hash for the user collection referencing the current NFT staking strategy.


```solidity
function hash(address _user, address _collection) external view returns (bytes32);
```

### hash

Creates a hash for the user collection referencing a custom NFT staking strategy.


```solidity
function hash(address _user, address _collection, address _strategy) external pure returns (bytes32);
```

### collectionHash

Calculates the hash for a collection and the current strategy.


```solidity
function collectionHash(address _collection) internal view returns (bytes32);
```

### collectionHash

Calculates the has for a collection and a specific strategy.


```solidity
function collectionHash(address _collection, address _strategy) internal pure returns (bytes32);
```

## Structs
### StakedNft

```solidity
struct StakedNft {
    uint epochStart;
    uint128 epochCount;
    uint128 tokensStaked;
}
```

