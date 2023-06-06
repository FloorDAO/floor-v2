# LlamapayCreateStream
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/llamapay/CreateStream.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Creates and funds a stream on the Llamapay platform.


## State Variables
### llamapayRouter
Our internally deployed Llamapay router


```solidity
LlamapayRouter public immutable llamapayRouter;
```


## Functions
### constructor

We assign any variable contract addresses in our constructor, allowing us
to have multiple deployed actions if any parameters change.


```solidity
constructor(LlamapayRouter _llamapayRouter);
```

### execute

Executes our request to create and fund a stream.

*If the Llamapay token contract does not yet exist, then additional gas will
be required to create it. For common tokens like USDC, this won't occur.*


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|Bytes to be cast to the `ActionRequest` struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint Total balance currently held by the stream|


## Structs
### ActionRequest
Store our required information to action a stream creation.


```solidity
struct ActionRequest {
    address to;
    address token;
    uint216 amountPerSec;
    uint amountToDeposit;
}
```

