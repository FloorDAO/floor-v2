# VoteMarket
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/bribes/VoteMarket.sol)

**Inherits:**
[EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), [IVoteMarket](/src/interfaces/bribes/VoteMarket.sol/contract.IVoteMarket.md), Pausable


## State Variables
### MINIMUM_EPOCHS
Minimum number of epochs for a Bribe


```solidity
uint8 public constant MINIMUM_EPOCHS = 1;
```


### DAO_FEE
The percentage of bribes that will be sent to the DAO


```solidity
uint8 public constant DAO_FEE = 2;
```


### CLAIM_WINDOW_EPOCHS
The number of epochs to claim generated rewards


```solidity
uint public constant CLAIM_WINDOW_EPOCHS = 4;
```


### feeCollector
The recipient of any fees collected. This should be set to the {Treasury}, or
to a specialist fee collection contract.


```solidity
address public immutable feeCollector;
```


### epochMerkles
Store our claim merkles that define the available rewards for each user across
all collections and bribes.


```solidity
mapping(uint => bytes32) public epochMerkles;
```


### epochCollectionVotes
Store the total number of votes cast against each collection at each epoch


```solidity
mapping(bytes32 => uint) public epochCollectionVotes;
```


### bribes
Stores a list of all bribes created, across past, live and future


```solidity
Bribe[] public bribes;
```


### collectionBribes
A mapping of collection addresses to an array of bribe array indexes


```solidity
mapping(address => uint[]) public collectionBribes;
```


### userClaimed
Store a list of users that have claimed. Each encoded bytes represents a user that
has claimed against a specific epoch and bribe ID.


```solidity
mapping(bytes32 => bool) internal userClaimed;
```


### isBlacklisted
Blacklisted addresses per bribe that aren't counted for rewards arithmetics.


```solidity
mapping(uint => mapping(address => bool)) public isBlacklisted;
```


### nextID
Track our bribe index iteration


```solidity
uint internal nextID;
```


### oracleWallet
Oracle wallet that has permission to write merkles


```solidity
address public oracleWallet;
```


### collectionRegistry
Store our collection registry


```solidity
ICollectionRegistry public immutable collectionRegistry;
```


## Functions
### constructor


```solidity
constructor(address _collectionRegistry, address _oracleWallet, address _feeCollector);
```

### createBribe

Create a new bribe that can be applied to either a New Collection War or
Sweep War.

*If a New Collection War bribe is being created, then the
`numberOfEpochs` value must be `1`.*


```solidity
function createBribe(
    address collection,
    address rewardToken,
    uint startEpoch,
    uint8 numberOfEpochs,
    uint maxRewardPerVote,
    uint totalRewardAmount,
    address[] calldata blacklist
) external whenNotPaused returns (uint newBribeID);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collection`|`address`|Address of the target collection.|
|`rewardToken`|`address`|Address of the ERC20 used or rewards.|
|`startEpoch`|`uint256`|The epoch to start offering the bribe.|
|`numberOfEpochs`|`uint8`|Number of periods.|
|`maxRewardPerVote`|`uint256`|Target Bias for the Gauge.|
|`totalRewardAmount`|`uint256`|Total Reward Added.|
|`blacklist`|`address[]`|Array of addresses to blacklist.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newBribeID`|`uint256`|of the bribe created.|


### claim

Claims against any bribes for a user.


```solidity
function claim(
    address account,
    uint[] calldata epoch,
    uint[] calldata bribeIds,
    address[] calldata collection,
    uint[] calldata votes,
    bytes32[][] calldata merkleProof
) external whenNotPaused;
```

### claimAll

Claims against all bribes in a collection for a user.


```solidity
function claimAll(
    address account,
    uint[] calldata epoch,
    address[] calldata collection,
    uint[] calldata votes,
    bytes32[][] calldata merkleProof
) external whenNotPaused;
```

### reclaimExpiredFunds

Allows the bribe creator to withdraw unclaimed funds when the claim window has expired.


```solidity
function reclaimExpiredFunds(uint bribeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bribeId`|`uint256`|The bribe ID to be reclaimed|


### _claim

Handles the internal logic to process a claim against a bribe.


```solidity
function _claim(uint bribeId, address account, uint epoch, address collection, uint votes, bytes32[] calldata merkleProof) internal;
```

### extendBribes

Allows our platform to increase the length of any sweep war bribes.

*This will be called by the {EpochManager} when a New Collection War is created
to extend the duration any Sweep War bribes that would be active at that epoch.*


```solidity
function extendBribes(uint epoch) external onlyEpochManager;
```

### hasUserClaimed

Checks if the user has already claimed against a bribe at an epoch.


```solidity
function hasUserClaimed(uint bribeId, uint epoch) external view returns (bool);
```

### _claimHash

Calculates our claim has for a bribe at an epoch.


```solidity
function _claimHash(uint bribeId, uint epoch) internal pure returns (bytes32);
```

### registerClaims

Allows our oracle wallet to upload a merkle root to define claims available against
a bribe when the epoch ends.


```solidity
function registerClaims(uint epoch, bytes32 merkleRoot, address[] calldata collections, uint[] calldata collectionVotes)
    external
    onlyOracle;
```

### setOracleWallet

Sets our authorised oracle wallet that will upload bribe claims.


```solidity
function setOracleWallet(address _oracleWallet) external onlyOwner;
```

### expireCollectionBribes

Allows our oracle wallet to expire collection bribes when they have expired.


```solidity
function expireCollectionBribes(address[] calldata collection, uint[] calldata index) external onlyOracle;
```

### bribeClaimOpen

Checks if a bribe claim window is still open.


```solidity
function bribeClaimOpen(uint bribeId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bribeId`|`uint256`|The bribe ID to be checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool If the claim window is still open|


### onlyOracle

Ensure that only our oracle wallet can call this function.


```solidity
modifier onlyOracle();
```

