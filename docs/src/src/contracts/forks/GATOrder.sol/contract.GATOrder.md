# GATOrder
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/forks/GATOrder.sol)

**Inherits:**
IERC1271


## State Variables
### owner

```solidity
address public immutable owner;
```


### sellToken

```solidity
IERC20 public immutable sellToken;
```


### validFrom

```solidity
uint32 public immutable validFrom;
```


### orderHash

```solidity
bytes32 public orderHash;
```


## Functions
### constructor


```solidity
constructor(address owner_, IERC20 sellToken_, uint32 validFrom_, bytes32 orderHash_, ICoWSwapSettlement settlement);
```

### isValidSignature


```solidity
function isValidSignature(bytes32 hash, bytes calldata) external view returns (bytes4 magicValue);
```

### cancel


```solidity
function cancel() public;
```

