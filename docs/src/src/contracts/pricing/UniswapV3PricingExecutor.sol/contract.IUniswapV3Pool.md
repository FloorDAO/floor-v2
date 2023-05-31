# IUniswapV3Pool
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/pricing/UniswapV3PricingExecutor.sol)

Partial interface for the {IUniswapV3Pool}. The full interface can be found here:
https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Pool.sol


## Functions
### slot0


```solidity
function slot0()
    external
    view
    returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
```

### liquidity


```solidity
function liquidity() external view returns (uint128);
```

### observe


```solidity
function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives);
```

### observations


```solidity
function observations(uint index)
    external
    view
    returns (uint32 blockTimestamp, int56 tickCumulative, uint160 liquidityCumulative, bool initialized);
```

