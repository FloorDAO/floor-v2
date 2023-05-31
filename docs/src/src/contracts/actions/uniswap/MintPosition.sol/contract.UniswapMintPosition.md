# UniswapMintPosition
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/uniswap/MintPosition.sol)

**Inherits:**
[UniswapActionBase](/src/contracts/actions/utils/UniswapActionBase.sol/contract.UniswapActionBase.md)

**Author:**
Twade

Mints a position against a Uniswap pool, minting an ERC721 that will be
passed to the sender. This ERC721 will referenced by subsequent Uniswap
actions to allow liquidity management and reward collection.


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

Mints an ERC721 position against a pool and provides initial liquidity.


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
    int24 tickLower;
    int24 tickUpper;
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    uint deadline;
}
```

