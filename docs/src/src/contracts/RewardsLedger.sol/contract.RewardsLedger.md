# RewardsLedger
[Git Source](https://github.com/FloorDAO/floor-v2/blob/37f09a5f4eb9f33e2f9b3f8c8a74d6362b1877d7/src/contracts/RewardsLedger.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [IRewardsLedger](/src/interfaces/RewardsLedger.sol/contract.IRewardsLedger.md)

*The rewards ledger holds all available rewards available to be claimed
by FLOOR users, as well as keeping a simple ledger of all tokens already
claimed.
The {RewardsLedger} will have the ability to transfer assets from {Treasury}
to recipient as it sees fit, whilst providing some separation of concerns.
Used the X2Y2 Drop contract as a starting point:
https://etherscan.io/address/0xe6949137b24ad50cce2cf6b124b3b874449a41fa#readContract*


## State Variables
### floor

```solidity
IFLOOR public immutable floor;
```


### veFloor

```solidity
IVeFLOOR public immutable veFloor;
```


### treasury

```solidity
address public immutable treasury;
```


### allocations

```solidity
mapping(address => mapping(address => uint256)) internal allocations;
```


### claimed

```solidity
mapping(address => mapping(address => uint256)) public claimed;
```


### tokens

```solidity
mapping(address => address[]) internal tokens;
```


### tokenStore

```solidity
mapping(address => mapping(address => bool)) internal tokenStore;
```


### paused

```solidity
bool public paused;
```


## Functions
### constructor

Set up our connection to the Treasury to ensure future calls only come from this
trusted source.


```solidity
constructor(address _authority, address _floor, address _veFloor, address _treasury) AuthorityControl(_authority);
```

### allocate

Allocate a set amount of a specific token to be accessible by the recipient. The token
amount won't actually be transferred to the {RewardsLedger}, but will instead just notify
us of the allocation and it will be transferred from the {Treasury} directly to the user
at point of claim.
This can only be called by an approved caller.


```solidity
function allocate(address recipient, address token, uint256 amount) external returns (uint256);
```

### available

Get the amount of available token for the recipient.


```solidity
function available(address recipient, address token) external view returns (uint256);
```

### availableTokens

Get all tokens available to the recipient, as well as the amounts of each token.


```solidity
function availableTokens(address recipient) external view returns (address[] memory, uint256[] memory);
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
function claim(address token, uint256 amount) external returns (uint256);
```

### pause

Allows our governance to pause rewards being claimed. This should be used
if an issue is found in the code causing incorrect rewards being distributed,
until a fix can be put in place.


```solidity
function pause(bool _paused) external onlyAdminRole;
```

