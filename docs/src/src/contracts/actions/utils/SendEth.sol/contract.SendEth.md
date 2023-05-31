# SendEth
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/utils/SendEth.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

This action allows us to send ETH.


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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The amount of ETH sent by the execution|


## Structs
### ActionRequest
Store our required information to action a swap.


```solidity
struct ActionRequest {
    address payable recipient;
    uint amount;
}
```

