# IUniswapV2Factory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/uniswap/IUniswapV2Factory.sol)


## Functions
### feeTo


```solidity
function feeTo() external view returns (address);
```

### feeToSetter


```solidity
function feeToSetter() external view returns (address);
```

### getPair


```solidity
function getPair(address tokenA, address tokenB) external view returns (address pair);
```

### allPairs


```solidity
function allPairs(uint) external view returns (address pair);
```

### allPairsLength


```solidity
function allPairsLength() external view returns (uint);
```

### createPair


```solidity
function createPair(address tokenA, address tokenB) external returns (address pair);
```

### setFeeTo


```solidity
function setFeeTo(address) external;
```

### setFeeToSetter


```solidity
function setFeeToSetter(address) external;
```

## Events
### PairCreated

```solidity
event PairCreated(address indexed token0, address indexed token1, address pair, uint);
```

