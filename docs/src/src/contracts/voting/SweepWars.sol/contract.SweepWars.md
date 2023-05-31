# SweepWars
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/voting/SweepWars.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), [ISweepWars](/src/interfaces/voting/SweepWars.sol/contract.ISweepWars.md)

Each epoch, unless we have set up a {NewCollectionWar} to run, then a sweep war will
take place. This contract will handle the voting and calculations for these wars.
When a Sweep War epoch ends, then the `snapshot` function will be called that finds the
top _x_ collections and their relative sweep amounts based on the votes cast.


## State Variables
### collectionVotes

```solidity
mapping(address => CollectionVote) collectionVotes;
```


### sampleSize
Keep a store of the number of collections we want to reward pick per epoch


```solidity
uint public sampleSize = 5;
```


### FLOOR_TOKEN_VOTE
Hardcoded address to map to the FLOOR token vault


```solidity
address public constant FLOOR_TOKEN_VOTE = address(1);
```


### collectionRegistry
Internal contract references


```solidity
ICollectionRegistry immutable collectionRegistry;
```


### vaultFactory

```solidity
IStrategyFactory immutable vaultFactory;
```


### veFloor

```solidity
VeFloorStaking immutable veFloor;
```


### treasury

```solidity
ITreasury immutable treasury;
```


### nftStaking

```solidity
INftStaking public nftStaking;
```


### userForVotes
We will need to maintain an internal structure to map the voters against
a vault address so that we can determine vote growth and reallocation. We
will additionally maintain a mapping of vault address to total amount that
will better allow for snapshots to be taken for less gas.
This will result in a slightly increased write, to provide a greatly
reduced read.
A collection of votes that the user currently has placed.
Mapping user address -> collection address -> amount.


```solidity
mapping(bytes32 => uint) private userForVotes;
```


### userAgainstVotes

```solidity
mapping(bytes32 => uint) private userAgainstVotes;
```


### totalUserVotes

```solidity
mapping(address => uint) private totalUserVotes;
```


## Functions
### constructor

Sets up our contract parameters.


```solidity
constructor(address _collectionRegistry, address _vaultFactory, address _veFloor, address _authority, address _treasury)
    AuthorityControl(_authority);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collectionRegistry`|`address`|Address of our {CollectionRegistry}|
|`_vaultFactory`|`address`|Address of our {VaultFactory}|
|`_veFloor`|`address`|Address of our {veFLOOR}|
|`_authority`|`address`|{AuthorityRegistry} contract address|
|`_treasury`|`address`||


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
function userVotesAvailable(address _user) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|User address being checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint Number of votes available to the user|


### vote

Allows a user to cast a vote using their veFloor allocation. We don't
need to monitor transfers as veFloor can only be minted or burned, and
we check the voters balance during the `snapshot` call.
A user can vote with a partial amount of their veFloor holdings, and when
it comes to calculating their voting power this will need to be taken into
consideration that it will be:
```
staked balance + (gains from staking * (total balance - staked balance)%)
```
The {Treasury} cannot vote with it's holdings, as it shouldn't be holding
any staked Floor.


```solidity
function vote(address _collection, uint _amount, bool _against) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The collection address being voted for|
|`_amount`|`uint256`|The number of votes the caller is casting|
|`_against`|`bool`|If the vote will be against the collection|


### votes


```solidity
function votes(address _collection) public view returns (int);
```

### votes

Gets the number of votes for a collection at a specific epoch.


```solidity
function votes(address _collection, uint _baseEpoch) public view returns (int votes_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The collection to check vote amount for|
|`_baseEpoch`|`uint256`|The epoch at which to get vote count|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`votes_`|`int256`|The number of votes at the epoch specified|


### revokeVotes

Allows a user to revoke their votes from vaults. This will free up the
user's available votes that can subsequently be voted again with.


```solidity
function revokeVotes(address[] memory _collections) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collections`|`address[]`||


### revokeAllUserVotes

Allows an authorised contract or wallet to revoke all user votes. This
can be called when the veFLOOR balance is reduced.


```solidity
function revokeAllUserVotes(address _account) external onlyRole(VOTE_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The user having their votes revoked|


### _revokeVotes


```solidity
function _revokeVotes(address _account, address[] memory _collections) internal;
```

### snapshot

The snapshot function will need to iterate over all collections that have
more than 0 votes against them. With that we will need to find each
vault's percentage share within each collection, in relation to others.
This percentage share will instruct the {Treasury} on how much additional
FLOOR to allocate to the users staked in the vaults. These rewards will be
distributed via the {VaultXToken} attached to each {Vault} that implements
the collection that is voted for.
We check against the `sampleSize` that has been set to only select the first
_x_ top voted collections. We find the vaults that align to the collection
and give them a sub-percentage of the collection's allocation based on the
total number of rewards generated within that collection.
This would distribute the vaults allocated rewards against the staked
percentage in the vault. Any Treasury holdings that would be given in rewards
are just deposited into the {Treasury} as FLOOR tokens.


```solidity
function snapshot(uint tokens, uint epoch) external view returns (address[] memory, uint[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`uint256`|The number of tokens rewards in the snapshot|
|`epoch`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|address[] The collections that were granted rewards|
|`<none>`|`uint256[]`|amounts[] The vote values of each collection|


### _topCollections

Finds the top voted collections based on the number of votes cast. This is quite
an intensive process for how simple it is, but essentially just orders creates an
ordered subset of the top _x_ voted collection addresses.


```solidity
function _topCollections(uint epoch) internal view returns (address[] memory, uint[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of collections limited to sample size|
|`<none>`|`uint256[]`|Respective vote power for each collection|


### setSampleSize

Allows an authenticated caller to update the `sampleSize`.

*This should be kept lower where possible for reduced gas spend*


```solidity
function setSampleSize(uint size) external onlyRole(VOTE_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`size`|`uint256`|The new `sampleSize`|


### setNftStaking

Allows our {NftStaking} contract to be updated.


```solidity
function setNftStaking(address _nftStaking) external onlyRole(VOTE_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_nftStaking`|`address`|The new {NftStaking} contract address|


### voteOptions

Provides a list of collection addresses that can be voted on. This will pull in
all approved collections as well as appending the {FLOOR} vote on the end, which
is a hardcoded address.


```solidity
function voteOptions() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|collections_ Collections (and {FLOOR} vote address) that can be voted on|


## Structs
### CollectionVote
Each collection has a stored struct that represents the current vote power, burn
rate and the last epoch that a vote was cast. These three parameters can be combined
to calculate current vote power at any epoch with minimal gas usage.


```solidity
struct CollectionVote {
    int power;
    int powerBurn;
    uint lastVoteEpoch;
}
```

