# SudoswapSellNftsForEth
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/sudoswap/SellNftsForEth.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Sends a set of NFTs to the pair in exchange for token.

*To compute the amount of token to that will be received, call
`bondingCurve.getSellInfo`.*


## Functions
### execute

Sells one or more NFTs into a Sudoswap pool for the paired token.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|Packed bytes that will map to our `ActionRequest` struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The amount of ETH or ERC20 received in exchange for the NFTs|


## Structs
### ActionRequest
Store our required information to action a sell.


```solidity
struct ActionRequest {
    address pair;
    uint[] nftIds;
    uint minExpectedTokenOutput;
}
```

