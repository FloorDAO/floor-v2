# RawTx
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/utils/RawTx.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

This action allows us to send bytes to a recipient contract.


## Functions
### execute

Sends a specific amount of ETH to a recipient.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|Packed bytes that will map to our `ActionRequest` struct|


### receive

Allow us to receive any refunds from the transaction back into our account.


```solidity
receive() external payable;
```

## Structs
### ActionRequest
Store our required information to action a raw transaction.


```solidity
struct ActionRequest {
    address payable recipient;
    bytes data;
}
```

