# UniswapClaimPoolRewards
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/uniswap/ClaimPoolRewards.sol)

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

Collects the fees associated with provided liquidity.

*The contract must hold the erc721 token before it can collect fees.*


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
    uint128 amount0;
    uint128 amount1;
}
```

