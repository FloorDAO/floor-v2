# ERC721Lockable
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/tokens/extensions/ERC721Lockable.sol)

**Inherits:**
ERC721, Ownable

Allows an ERC721 token to be softlocked by an external contract. We piggyback
the existing approval logic to allow the external contract to have locking rights.
By allowing a token to be softlocked, we can get claim timelocked rewards or
benfits without the requirement of transferring the token away from the user.
In addition, we also allow for staking contracts to be specified that will allow
a user to soft lock their token, without the token being in direct ownership of
the calling user. It will, however, require that the


## State Variables
### tokenLocks
Maps token IDs to locks


```solidity
mapping(uint => TokenLock) internal tokenLocks;
```


### heldStakes
Maps token IDs to a user that has it staked in an approved staking contract.


```solidity
mapping(uint => address) public heldStakes;
```


### approvedLockers
Maps an approved locking address to a token ID.


```solidity
mapping(uint => address) public approvedLockers;
```


### approvedStakers
List of approved stakers


```solidity
address[] public approvedStakers;
```


## Functions
### isLocked

Checks if the token ID is currently locked, based on the lock timestamp.


```solidity
function isLocked(uint tokenId) external view returns (bool);
```

### lockedBy

The address of the staker that has locked the token ID. If the token is not
currently locked, then a zero address will be returned.


```solidity
function lockedBy(uint tokenId) external view returns (address);
```

### lockedUntil

The timestamp that the token is locked until. If the token is not currently
locked then `0` will be returned.


```solidity
function lockedUntil(uint tokenId) external view returns (uint);
```

### approveLocker

Approves an address to lock the token, in the same manner that `approve` works.


```solidity
function approveLocker(address to, uint tokenId) external;
```

### lock

Locks the token ID


```solidity
function lock(address user, uint tokenId, uint96 unlocksAt) external;
```

### unlock

Allows a locker to unlock a token that they currently have locked.


```solidity
function unlock(uint tokenId) external;
```

### setApprovedStaker

Allows a new staker contract to be approved to lock the token.


```solidity
function setApprovedStaker(address staker, bool approved) external onlyOwner;
```

### _beforeTokenTransfer

Before a token is transferred, we need to check if it is being sent to an approved
staking contract to maintain.


```solidity
function _beforeTokenTransfer(address from, address to, uint firstTokenId, uint batchSize) internal virtual override (ERC721);
```

### _isApprovedStaker

Check if an address is present in our approved stakers list.


```solidity
function _isApprovedStaker(address staker) internal view returns (bool);
```

## Structs
### TokenLock
Holds information about our token locks.


```solidity
struct TokenLock {
    address locker;
    uint96 unlocksAt;
}
```

