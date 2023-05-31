# UniswapAddLiquidity
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/uniswap/AddLiquidity.sol)

**Inherits:**
[UniswapActionBase](/src/contracts/actions/utils/UniswapActionBase.sol/contract.UniswapActionBase.md)

**Author:**
Twade

Adds liquidity against an existing Uniswap ERC721 position.


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

Adds liquidity to an existing ERC721 position.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

### _execute


```solidity
function _execute(ActionRequest memory request) internal requiresUniswapToken(request.tokenId) returns (uint);
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    uint tokenId;
    address token0;
    address token1;
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
}
```

