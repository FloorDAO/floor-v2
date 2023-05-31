# IVoteMarket
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/bribes/VoteMarket.sol)


## Functions
### MINIMUM_EPOCHS

Minimum number of epochs for a Bribe


```solidity
function MINIMUM_EPOCHS() external returns (uint8);
```

### DAO_FEE

The percentage of bribes that will be sent to the DAO


```solidity
function DAO_FEE() external returns (uint8);
```

### feeCollector

The recipient of any fees collected. This should be set to the {Treasury}, or
to a specialist fee collection contract.


```solidity
function feeCollector() external returns (address);
```

### isBlacklisted

Store our claim merkles that define the available rewards for each user across
all collections and bribes.
Stores a list of all bribes created, across past, live and future
A mapping of collection addresses to an array of bribe array indexes
Blacklisted addresses per bribe that aren't counted for rewards arithmetics.


```solidity
function isBlacklisted(uint bribeId, address account) external returns (bool);
```

### oracleWallet

Oracle wallet that has permission to write merkles


```solidity
function oracleWallet() external returns (address);
```

### createBribe

Create a new bribe.


```solidity
function createBribe(
    address collection,
    address rewardToken,
    uint startEpoch,
    uint8 numberOfEpochs,
    uint maxRewardPerVote,
    uint totalRewardAmount,
    address[] calldata blacklist
) external returns (uint newBribeID);
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


```solidity
function claim(
    address account,
    uint[] calldata epoch,
    uint[] calldata bribeIds,
    address[] calldata collection,
    uint[] calldata votes,
    bytes32[][] calldata merkleProof
) external;
```

### claimAll


```solidity
function claimAll(
    address account,
    uint[] calldata epoch,
    address[] calldata collection,
    uint[] calldata votes,
    bytes32[][] calldata merkleProof
) external;
```

### hasUserClaimed


```solidity
function hasUserClaimed(uint bribeId, uint epoch) external view returns (bool);
```

### registerClaims


```solidity
function registerClaims(uint epoch, bytes32 merkleRoot, address[] calldata collections, uint[] calldata collectionVotes) external;
```

### setOracleWallet


```solidity
function setOracleWallet(address _oracleWallet) external;
```

### extendBribes


```solidity
function extendBribes(uint epoch) external;
```

### expireCollectionBribes


```solidity
function expireCollectionBribes(address[] calldata collection, uint[] calldata index) external;
```

## Events
### BribeCreated
Fired when a new bribe is created


```solidity
event BribeCreated(uint bribeId);
```

### Claimed
Fired when a user claims their bribe allocation


```solidity
event Claimed(address account, address rewardToken, uint bribeId, uint amount, uint epoch);
```

### ClaimRegistered
Fired when a new claim allocation is assigned for an epoch


```solidity
event ClaimRegistered(uint epoch, bytes32 merkleRoot);
```

## Structs
### Bribe
Bribe struct requirements.


```solidity
struct Bribe {
    uint startEpoch;
    uint maxRewardPerVote;
    uint remainingRewards;
    uint totalRewardAmount;
    address collection;
    address rewardToken;
    address creator;
    uint8 numberOfEpochs;
}
```

