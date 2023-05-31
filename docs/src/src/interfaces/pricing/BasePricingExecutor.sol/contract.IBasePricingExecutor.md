# IBasePricingExecutor
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/pricing/BasePricingExecutor.sol)

Pricing Executors will provide our Treasury with the pricing knowledge needed
to equate a reward token to that of FLOOR. Each executor will implement a single
pricing strategy that can be implemented by the Treasury.
This base strategy will need to be inherited and extended upon by other pricing
exectors to ensure that the required logic and functionality is made available.


## Functions
### name

Name of the pricing executor.


```solidity
function name() external view returns (string memory);
```

### getETHPrice

Gets our current mapped price of a token to ETH.


```solidity
function getETHPrice(address token) external returns (uint);
```

### getETHPrices

Gets our current mapped price of multiple tokens to ETH.


```solidity
function getETHPrices(address[] memory token) external returns (uint[] memory);
```

### getFloorPrice

Gets our current mapped price of a token to FLOOR.


```solidity
function getFloorPrice(address token) external returns (uint);
```

### getFloorPrices

Gets our current mapped price of multiple tokens to FLOOR.


```solidity
function getFloorPrices(address[] memory token) external returns (uint[] memory);
```

### getLatestFloorPrice

Gets the latest stored FLOOR token price equivalent to a token. If the price has
not been queried before, then we cache and return a new price.


```solidity
function getLatestFloorPrice(address token) external view returns (uint);
```

### getLiquidity

..


```solidity
function getLiquidity(address token) external returns (uint);
```

## Events
### TokenPriceUpdated
*When a token price is updated*


```solidity
event TokenPriceUpdated(address token, uint amount);
```

