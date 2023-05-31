# INewCollectionWars
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/voting/NewCollectionWars.sol)


## Functions
### userVotes

Stores the number of votes a user has placed against a war collection


```solidity
function userVotes(bytes32) external view returns (uint);
```

### collectionSpotPrice

Stores the floor spot price of a collection token against a war collection


```solidity
function collectionSpotPrice(bytes32) external view returns (uint);
```

### collectionVotes

Stores the total number of votes against a war collection


```solidity
function collectionVotes(bytes32) external view returns (uint);
```

### collectionNftVotes


```solidity
function collectionNftVotes(bytes32) external view returns (uint);
```

### userCollectionVote

Stores which collection the user has cast their votes towards to allow for
reallocation on subsequent votes if needed.


```solidity
function userCollectionVote(bytes32) external view returns (address);
```

### floorWarWinner

Stores the address of the collection that won a Floor War


```solidity
function floorWarWinner(uint _epoch) external view returns (address);
```

### is1155

Stores if a collection has been flagged as ERC1155


```solidity
function is1155(address) external returns (bool);
```

### collectionEpochLock

Stores the unlock epoch of a collection in a floor war


```solidity
function collectionEpochLock(bytes32) external returns (uint);
```

### userVotingPower

The total voting power of a user, regardless of if they have cast votes
or not.


```solidity
function userVotingPower(address _user) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|User address being checked|


### userVotesAvailable

The total number of votes that a user has available.


```solidity
function userVotesAvailable(uint _war, address _user) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_war`|`uint256`||
|`_user`|`address`|User address being checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint Number of votes available to the user|


### vote

Allows the user to cast 100% of their voting power against an individual
collection. If the user has already voted on the FloorWar then this will
additionally reallocate their votes.


```solidity
function vote(address collection) external;
```

### optionVote

Allows an approved contract to submit option-related votes against a collection
in the current war.


```solidity
function optionVote(address sender, uint war, address collection, uint votingPower) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address of the user that staked the token|
|`war`|`uint256`||
|`collection`|`address`|The collection to cast the vote against|
|`votingPower`|`uint256`|The voting power added from the option creation|


### revokeVotes

Revokes a user's current votes in the current war.

*This is used when a user unstakes their floor*


```solidity
function revokeVotes(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the account that is having their vote revoked|


### createFloorWar

Allow an authorised user to create a new floor war to start with a range of
collections from a specific epoch.


```solidity
function createFloorWar(uint epoch, address[] calldata collections, bool[] calldata isErc1155, uint[] calldata floorPrices)
    external
    returns (uint);
```

### startFloorWar

Sets a scheduled {FloorWar} to be active.

*This function is called by the {EpochManager} when a new epoch starts*


```solidity
function startFloorWar(uint index) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the {FloorWar} being started|


### endFloorWar

When the epoch has come to an end, this function will be called to finalise
the votes and decide which collection has won. This collection will then need
to be added to the {CollectionRegistry}.
Any NFTs that have been staked will be timelocked for an additional epoch to
give the DAO time to exercise or reject any options.

*We can't action this in one single call as we will need information about
the underlying NFTX token as well.*


```solidity
function endFloorWar() external returns (address highestVoteCollection);
```

### updateCollectionFloorPrice

Allows us to update our collection floor prices if we have seen a noticable difference
since the start of the epoch. This will need to be called for this reason as the floor
price of the collection heavily determines the amount of voting power awarded when
creating an option.


```solidity
function updateCollectionFloorPrice(address collection, uint floorPrice) external;
```

### setOptionsContract

Allows our options contract to be updated.


```solidity
function setOptionsContract(address _contract) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|The new contract to use|


### isCollectionInWar

Check if a collection is in a FloorWar.


```solidity
function isCollectionInWar(bytes32 warCollection) external view returns (bool);
```

## Events
### VoteCast
Sent when a user casts a vote


```solidity
event VoteCast(address sender, address collection, uint userVotes, uint collectionVotes);
```

### VoteRevoked
Sent when a collection vote is revoked


```solidity
event VoteRevoked(address sender, address collection, uint collectionVotes);
```

### NftVoteCast
Sent when a collection NFT is staked to vote


```solidity
event NftVoteCast(address sender, uint war, address collection, uint collectionVotes, uint collectionNftVotes);
```

### CollectionAdditionWarCreated
Sent when a Collection Addition War is created


```solidity
event CollectionAdditionWarCreated(uint epoch, address[] collections, uint[] floorPrices);
```

### CollectionAdditionWarStarted
Sent when a Collection Addition War is started


```solidity
event CollectionAdditionWarStarted(uint warIndex);
```

### CollectionAdditionWarEnded
Sent when a Collection Addition War ends


```solidity
event CollectionAdditionWarEnded(uint warIndex);
```

### CollectionExercised
Sent when Collection Addition War NFTs are exercised


```solidity
event CollectionExercised(uint warIndex, address collection, uint value);
```

## Structs
### FloorWar
For each FloorWar that is created, this structure will be created. When
the epoch ends, the FloorWar will remain and will be updated with information
on the winning collection and the votes attributed to each collection.


```solidity
struct FloorWar {
    uint index;
    uint startEpoch;
    address[] collections;
}
```

