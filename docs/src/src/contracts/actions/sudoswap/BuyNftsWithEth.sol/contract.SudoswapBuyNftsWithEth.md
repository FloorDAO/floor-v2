# SudoswapBuyNftsWithEth
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/sudoswap/BuyNftsWithEth.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Sends token to the pair in exchange for any `numNFTs` NFTs.


## State Variables
### ethRecipient
Temporary store for a fallback ETH recipient


```solidity
address ethRecipient;
```


## Functions
### execute

Buys one or more NFTs from a Sudoswap pool using the paired token.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint spent);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|Packed bytes that will map to our `ActionRequest` struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`spent`|`uint256`|The amount of ETH or ERC20 spent on the execution|


### receive


```solidity
receive() external payable;
```

## Structs
### ActionRequest
Store our required information to action a buy.


```solidity
struct ActionRequest {
    address pair;
    uint numNFTs;
    uint maxExpectedTokenInput;
    address nftRecipient;
}
```

