# UniswapV3Strategy
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/strategies/UniswapV3Strategy.sol)

**Inherits:**
[BaseStrategy](/src/contracts/strategies/BaseStrategy.sol/contract.BaseStrategy.md)

Sets up a strategy that interacts with Uniswap.


## State Variables
### tokenId
Once our token has been minted, we can store the ID


```solidity
uint public tokenId;
```


### params
An array of tokens supported by the strategy


```solidity
InitializeParams public params;
```


### positionManager
Stores our Uniswap position manager


```solidity
IUniswapV3NonfungiblePositionManager public positionManager;
```


## Functions
### initialize

Sets up our contract variables.


```solidity
function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`bytes32`|The name of the strategy|
|`_strategyId`|`uint256`|ID index of the strategy created|
|`_initData`|`bytes`|Encoded data to be decoded|


### deposit

Adds liquidity against an existing Uniswap ERC721 position.
/// @param amount0Desired - The desired amount of token0 that should be supplied,
/// @param amount1Desired - The desired amount of token1 that should be supplied,
/// @param amount0Min - The minimum amount of token0 that should be supplied,
/// @param amount1Min - The minimum amount of token1 that should be supplied,
/// @param deadline - The time by which the transaction must be included to effect the change


```solidity
function deposit(uint amount0Desired, uint amount1Desired, uint amount0Min, uint amount1Min, uint deadline)
    external
    returns (uint liquidity, uint amount0, uint amount1);
```

### withdraw


```solidity
function withdraw(address recipient, uint amount0Min, uint amount1Min, uint deadline, uint128 liquidity) external nonReentrant onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`||
|`amount0Min`|`uint256`|- The minimum amount of token0 that should be accounted for the burned liquidity,|
|`amount1Min`|`uint256`|- The minimum amount of token1 that should be accounted for the burned liquidity,|
|`deadline`|`uint256`|- The time by which the transaction must be included to effect the change|
|`liquidity`|`uint128`||


### available

Gets rewards that are available to harvest.


```solidity
function available() external view override returns (address[] memory tokens_, uint[] memory amounts_);
```

### harvest

There will never be any rewards to harvest in this strategy.


```solidity
function harvest(address _recipient) external override onlyOwner;
```

### validTokens

Returns an array of tokens that the strategy supports.


```solidity
function validTokens() external view override returns (address[] memory tokens_);
```

### onERC721Received

Implementing `onERC721Received` so this contract can receive custody of erc721 tokens.

*Note that the operator is recorded as the owner of the deposited NFT.*


```solidity
function onERC721Received(address, address, uint, bytes calldata) external view returns (bytes4);
```

## Structs
### InitializeParams

```solidity
struct InitializeParams {
    address token0;
    address token1;
    uint24 fee;
    uint96 sqrtPriceX96;
    int24 tickLower;
    int24 tickUpper;
    address pool;
    address positionManager;
}
```

