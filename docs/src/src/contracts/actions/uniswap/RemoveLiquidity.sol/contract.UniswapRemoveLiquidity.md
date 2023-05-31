# UniswapRemoveLiquidity
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/uniswap/RemoveLiquidity.sol)

**Inherits:**
[UniswapActionBase](/src/contracts/actions/utils/UniswapActionBase.sol/contract.UniswapActionBase.md)

Decreases liquidity from a position represented by tokenID.


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

Removes liquidity from an existing ERC721 position.

*To collect the liquidity generated, we will need to subsequently call `collect`
on the pool using the {UniswapClaimPoolRewards} action.*


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
    uint128 liquidity;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
}
```

