# SushiswapRemoveLiquidity
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/sushiswap/RemoveLiquidity.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Allows liquidity to be removed from a Sushiswap position.


## State Variables
### WETH_TOKEN
WETH token address


```solidity
address internal constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


### uniswapRouter
Uniswap contract references


```solidity
IUniswapV2Router01 public immutable uniswapRouter;
```


### uniswapFactory

```solidity
IUniswapV2Factory public immutable uniswapFactory;
```


## Functions
### constructor

Sets up our immutable Sushiswap contract references.


```solidity
constructor(address _uniswapRouter, address _uniswapFactory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_uniswapRouter`|`address`|The address of the external Uniswap router contract|
|`_uniswapFactory`|`address`|The address of the external Uniswap factory contract|


### execute

Removes liquidity to the Sushiswap pool.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    address tokenA;
    address tokenB;
    address to;
    uint liquidity;
    uint amountAMin;
    uint amountBMin;
    uint deadline;
}
```

