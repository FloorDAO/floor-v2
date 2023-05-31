# IUniswapV3Factory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/pricing/UniswapV3PricingExecutor.sol)

Partial interface for the {IUniswapV3Factory} contract. The full interface can be found here:
https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Factory.sol


## Functions
### getPool


```solidity
function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
```

