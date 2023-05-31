# IUniswapV3NonfungiblePositionManager
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol)


## Functions
### mint


```solidity
function mint(MintParams calldata params) external payable returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1);
```

### increaseLiquidity


```solidity
function increaseLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    returns (uint128 liquidity, uint amount0, uint amount1);
```

### decreaseLiquidity


```solidity
function decreaseLiquidity(DecreaseLiquidityParams calldata params) external payable returns (uint amount0, uint amount1);
```

### collect


```solidity
function collect(CollectParams calldata params) external payable returns (uint amount0, uint amount1);
```

### positions


```solidity
function positions(uint tokenId)
    external
    view
    returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint feeGrowthInside0LastX128,
        uint feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
```

### balanceOf


```solidity
function balanceOf(address owner) external view returns (uint balance);
```

### tokenOfOwnerByIndex


```solidity
function tokenOfOwnerByIndex(address owner, uint index) external view returns (uint tokenId);
```

### approve


```solidity
function approve(address to, uint tokenId) external;
```

### createAndInitializePoolIfNecessary

Creates a new pool if it does not exist, then initializes if not initialized

*This method can be bundled with others via IMulticall for the first action (e.g. mint) performed against a pool*


```solidity
function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
    external
    payable
    returns (address pool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token0`|`address`|The contract address of token0 of the pool|
|`token1`|`address`|The contract address of token1 of the pool|
|`fee`|`uint24`|The fee amount of the v3 pool for the specified token pair|
|`sqrtPriceX96`|`uint160`|The initial square root price of the pool as a Q64.96 value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pool`|`address`|Returns the pool address based on the pair of tokens and fee, will return the newly created pool address if necessary|


### safeTransferFrom

*Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
are aware of the ERC721 protocol to prevent tokens from being forever locked.
Requirements:
- `from` cannot be the zero address.
- `to` cannot be the zero address.
- `tokenId` token must exist and be owned by `from`.
- If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
- If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
Emits a {Transfer} event.*


```solidity
function safeTransferFrom(address from, address to, uint tokenId) external;
```

## Structs
### MintParams

```solidity
struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    address recipient;
    uint deadline;
}
```

### IncreaseLiquidityParams

```solidity
struct IncreaseLiquidityParams {
    uint tokenId;
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
}
```

### DecreaseLiquidityParams

```solidity
struct DecreaseLiquidityParams {
    uint tokenId;
    uint128 liquidity;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
}
```

### CollectParams

```solidity
struct CollectParams {
    uint tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
}
```

