# IRewardsLedger
[Git Source](https://github.com/FloorDAO/floor-v2/blob/37f09a5f4eb9f33e2f9b3f8c8a74d6362b1877d7/src/interfaces/RewardsLedger.sol)

*The rewards ledger holds all available rewards available to be claimed
by FLOOR users, as well as keeping a simple ledger of all tokens already
claimed.
The {RewardsLedger} will have the ability to transfer assets from {Treasury}
to recipient as it sees fit, whilst providing some separation of concerns.
Used the X2Y2 Drop contract as a starting point:
https://etherscan.io/address/0xe6949137b24ad50cce2cf6b124b3b874449a41fa#readContract*


## Functions
### treasury

Returns the address of the {Treasury} contract.


```solidity
function treasury() external view returns (address);
```

### allocate

Allocated a set amount of a specific token to be accessible by the recipient. This
information will be stored in a {RewardToken}, either creating or updating the
struct. This can only be called by an approved caller.


```solidity
function allocate(address recipient, address token, uint256 amount) external returns (uint256 available);
```

### available

Get the amount of available token for the recipient.


```solidity
function available(address recipient, address token) external view returns (uint256);
```

### availableTokens

Get all tokens available to the recipient, as well as the amounts of each token.


```solidity
function availableTokens(address recipient)
    external
    view
    returns (address[] memory tokens_, uint256[] memory amounts_);
```

### claim

These tokens are stored in the {Treasury}, but will be allowed access from
this contract to allow them to be claimed at a later time.
A user will be able to claim the token as long as the {Treasury} holds
the respective token (which it always should) and has sufficient balance
in `available`.
If the user is claiming FLOOR token from the {Treasury}, then it will need
to call the `mint` function as the {Treasury} won't hold it already.


```solidity
function claim(address token, uint256 amount) external returns (uint256 totalClaimed);
```

### pause

Allows our governance to pause rewards being claimed. This should be used
if an issue is found in the code causing incorrect rewards being distributed,
until a fix can be put in place.


```solidity
function pause(bool pause) external;
```

## Events
### RewardsAllocated
*Emitted when rewards are allocated to a user*


```solidity
event RewardsAllocated(address recipient, address token, uint256 amount);
```

### RewardsClaimed
*Emitted when rewards are claimed by a user*


```solidity
event RewardsClaimed(address recipient, address token, uint256 amount);
```

### RewardsPaused
*Emitted when rewards claiming is paused or unpaused*


```solidity
event RewardsPaused(bool paused);
```

