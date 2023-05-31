# NewCollectionWars
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/voting/NewCollectionWars.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), [INewCollectionWars](/src/interfaces/voting/NewCollectionWars.sol/contract.INewCollectionWars.md)

When a new collection is going to be voted in to the ecosystem, we set up a New Collection
War with a range of collections that will then be open to vote on. Votes will be made by
casting veFloor against a specific collection.
There is the option of creating an exercisable option that will additionally generate a
voting power through a calculator. This is accomodated in this contract, but the logic
will be encapsulated in a separate contract.
When the {EpochManager} determines that an epoch has ended, if there is an active New
Collection War, then `endFloorWar` will be called.


## State Variables
### veFloor
Internal contract mappings


```solidity
VeFloorStaking public immutable veFloor;
```


### newCollectionWarOptions
Internal options contract mapping


```solidity
INewCollectionWarOptions public newCollectionWarOptions;
```


### currentWar
Stores a collection of all the NewCollectionWars that have been started


```solidity
FloorWar public currentWar;
```


### wars

```solidity
FloorWar[] public wars;
```


### floorWarWinner
Stores the address of the collection that won a Floor War


```solidity
mapping(uint => address) public floorWarWinner;
```


### collectionEpochLock
Stores the unlock epoch of a collection in a floor war


```solidity
mapping(bytes32 => uint) public collectionEpochLock;
```


### is1155
Stores if a collection has been flagged as ERC1155


```solidity
mapping(address => bool) public is1155;
```


### userVotes
Stores the number of votes a user has placed against a war collection


```solidity
mapping(bytes32 => uint) public userVotes;
```


### collectionSpotPrice
Stores the floor spot price of a collection token against a war collection


```solidity
mapping(bytes32 => uint) public collectionSpotPrice;
```


### collectionVotes
Stores the total number of votes against a war collection


```solidity
mapping(bytes32 => uint) public collectionVotes;
```


### collectionNftVotes

```solidity
mapping(bytes32 => uint) public collectionNftVotes;
```


### userCollectionVote
Stores which collection the user has cast their votes towards to allow for
reallocation on subsequent votes if needed.


```solidity
mapping(bytes32 => address) public userCollectionVote;
```


## Functions
### constructor

Sets our internal contract addresses.


```solidity
constructor(address _authority, address _veFloor) AuthorityControl(_authority);
```

### currentWarIndex

Gets the index of the current war, returning 0 if none are set.


```solidity
function currentWarIndex() public view returns (uint);
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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Voting power of the user|


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
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collection`|`address`|The address of the collection to cast vote against|


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
function revokeVotes(address account) external onlyRole(VOTE_MANAGER);
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
    onlyOwner
    returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The epoch that the war will take place in|
|`collections`|`address[]`|The collections that will be taking part|
|`isErc1155`|`bool[]`|If the corresponding collection is an ERC1155 standard|
|`floorPrices`|`uint256[]`|The ETH floor value of the corresponding collection|


### startFloorWar

Sets a scheduled {FloorWar} to be active.

*This function is called by the {EpochManager} when a new epoch starts*


```solidity
function startFloorWar(uint index) external onlyEpochManager;
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
function endFloorWar() external onlyRole(COLLECTION_MANAGER) returns (address highestVoteCollection);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`highestVoteCollection`|`address`|The collection address that received the most votes|


### updateCollectionFloorPrice

Allows us to update our collection floor prices if we have seen a noticable difference
since the start of the epoch. This will need to be called for this reason as the floor
price of the collection heavily determines the amount of voting power awarded when
creating an option.


```solidity
function updateCollectionFloorPrice(address collection, uint floorPrice) external onlyOwner;
```

### setOptionsContract

Allows our options contract to be updated.


```solidity
function setOptionsContract(address _contract) external onlyOwner;
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

