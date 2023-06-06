# GaugeWeightVote
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/voting/GaugeWeightVote.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [IGaugeWeightVote](/src/interfaces/voting/GaugeWeightVote.sol/contract.IGaugeWeightVote.md)

The GWV will allow users to assign their veFloor position to a vault, or
optionally case it to a veFloor, which will use a constant value. As the
vaults will be rendered as an address, the veFloor vote will take a NULL
address value.


## State Variables
### sampleSize
Keep a store of the number of collections we want to reward pick per epoch


```solidity
uint public sampleSize = 5;
```


### FLOOR_TOKEN_VOTE
Hardcoded address to map to the FLOOR token vault


```solidity
address public FLOOR_TOKEN_VOTE = address(1);
```


### FLOOR_TOKEN_VOTE_XTOKEN

```solidity
address internal FLOOR_TOKEN_VOTE_XTOKEN;
```


### collectionRegistry
Internal contract references


```solidity
ICollectionRegistry immutable collectionRegistry;
```


### vaultFactory

```solidity
IVaultFactory immutable vaultFactory;
```


### veFloor

```solidity
IVeFLOOR immutable veFloor;
```


### userVotes
We will need to maintain an internal structure to map the voters against
a vault address so that we can determine vote growth and reallocation. We
will additionally maintain a mapping of vault address to total amount that
will better allow for snapshots to be taken for less gas.
This will result in a slightly increased write, to provide a greatly
reduced read.
A collection of votes that the user currently has placed.
Mapping user address -> collection address -> amount.


```solidity
mapping(address => mapping(address => uint)) private userVotes;
```


### totalUserVotes

```solidity
mapping(address => uint) private totalUserVotes;
```


### votes
Mapping collection address -> total amount.


```solidity
mapping(address => uint) public votes;
```


### userVoteCollections
Store a list of collections each user has voted on to reduce the
number of iterations.


```solidity
mapping(address => address[]) public userVoteCollections;
```


### yieldStorage
Storage for yield calculations


```solidity
mapping(address => uint) internal yieldStorage;
```


### lastSnapshot
Track the previous snapshot that was made


```solidity
uint public lastSnapshot;
```


## Functions
### constructor

Sets up our contract parameters.


```solidity
constructor(address _collectionRegistry, address _vaultFactory, address _veFloor, address _authority) AuthorityControl(_authority);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collectionRegistry`|`address`|Address of our {CollectionRegistry}|
|`_vaultFactory`|`address`|Address of our {VaultFactory}|
|`_veFloor`|`address`|Address of our {veFLOOR}|
|`_authority`|`address`|{AuthorityRegistry} contract address|


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
function vote(address _collection, uint _amount) external returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The collection address being voted for|
|`_amount`|`uint256`|The number of votes the caller is casting|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The total number of votes now placed for the collection|


### revokeVotes

Allows a user to revoke their votes from vaults. This will free up the
user's available votes that can subsequently be voted again with.


```solidity
function revokeVotes(address[] memory _collection, uint[] memory _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address[]`||
|`_amount`|`uint256[]`||


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
function snapshot(uint tokens) external returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`uint256`|The number of tokens rewards in the snapshot|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|address[] The vaults that were granted rewards|


### _topCollections

Finds the top voted collections based on the number of votes cast. This is quite
an intensive process for how simple it is, but essentially just orders creates an
ordered subset of the top _x_ voted collection addresses.


```solidity
function _topCollections() internal view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of collections|


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


### voteOptions

Provides a list of collection addresses that can be voted on. This will pull in
all approved collections as well as appending the {FLOOR} vote on the end, which
is a hardcoded address.


```solidity
function voteOptions() external view returns (address[] memory collections_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`collections_`|`address[]`|Collections (and {FLOOR} vote address) that can be voted on|


### _getCollectionVaultRewardsIndicator

Returns a reward weighting for the vault, allowing us to segment the collection rewards
yield to holders based on this value. A vault with a higher indicator value will receive
a higher percentage of rewards allocated to the collection it implements.


```solidity
function _getCollectionVaultRewardsIndicator(address vault) internal returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Address of the vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Reward weighting|


### _deleteUserCollectionVote

Removes a user's votes from a collection and refunds gas where possible.


```solidity
function _deleteUserCollectionVote(address account, address collection) internal returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Account having their votes revoked|
|`collection`|`address`|The collection the votes are being revoked from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|If votes were revoked successfully|


### setFloorXToken

Allows an authenticated called to update our {VaultXToken} address that is used
for {FLOOR} vote reward distributions.


```solidity
function setFloorXToken(address _xToken) public onlyRole(VOTE_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_xToken`|`address`|Address of our deployed {VaultXToken} contract|


