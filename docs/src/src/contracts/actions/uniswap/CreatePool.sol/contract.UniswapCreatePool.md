# UniswapCreatePool
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/uniswap/CreatePool.sol)

**Inherits:**
[UniswapActionBase](/src/contracts/actions/utils/UniswapActionBase.sol/contract.UniswapActionBase.md)

**Author:**
Twade

Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
already present with the fee amount specified.


## Functions
### constructor

Assigns our Uniswap V3 position manager contract that will be called at
various points to interact with the platform.


```solidity
constructor(address _positionManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_positionManager`|`address`|The address of the UV3 position manager contract|


### execute

Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
already present with the fee amount specified. If the pool does already exist,
then the existing pool address will be returned in the call anyway.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    address token0;
    address token1;
    uint24 fee;
    uint160 sqrtPriceX96;
}
```

