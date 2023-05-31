# SushiswapAddLiquidity
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/sushiswap/AddLiquidity.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Allows liquidity to be added to a Sushiswap position.


## State Variables
### ETH_TOKEN
ETH token address


```solidity
address internal constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


### uniswapRouter
Uniswap contract references


```solidity
IUniswapV2Router01 public immutable uniswapRouter;
```


## Functions
### constructor

Sets up our immutable Sushiswap contract references.


```solidity
constructor(address _uniswapRouter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_uniswapRouter`|`address`|The address of the external Uniswap router contract|


### execute

Adds liquidity to the Sushiswap pool, with logic varying if one of the tokens
is specified to be ETH, rather than an ERC20.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

### _addEthLiquidity


```solidity
function _addEthLiquidity(ActionRequest memory request) internal returns (uint);
```

### _addTokenLiquidity


```solidity
function _addTokenLiquidity(ActionRequest memory request) internal returns (uint);
```

### receive

Allows the contract to receive ETH as an intermediary.


```solidity
receive() external payable;
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    address tokenA;
    address tokenB;
    address to;
    uint amountADesired;
    uint amountBDesired;
    uint amountAMin;
    uint amountBMin;
    uint deadline;
}
```

