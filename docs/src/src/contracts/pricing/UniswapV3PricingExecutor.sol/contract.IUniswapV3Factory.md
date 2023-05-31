# IUniswapV3Factory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/pricing/UniswapV3PricingExecutor.sol)

Partial interface for the {IUniswapV3Factory} contract. The full interface can be found here:
https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Factory.sol


## Functions
### getPool


```solidity
function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
```

