# LlamapayRouter
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/llamapay/LlamapayRouter.sol)

**Inherits:**
Pausable

The Llamapay router acts as an intermediary contract that our Llamapay actions
make their calls through. This groups common logic and handles our edge cases.


## State Variables
### llamaPayFactory
Interface for the externally deployed {LlamaPayFactory} contract.


```solidity
ILlamaPayFactory public immutable llamaPayFactory;
```


## Functions
### constructor

We assign any variable contract addresses in our constructor, allowing us
to have multiple deployed actions if any parameters change.


```solidity
constructor(address _llamaPayFactory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_llamaPayFactory`|`address`|Address of the LlamaPay Factory contract|


### createStream

Create and funds a token stream to a recipient.


```solidity
function createStream(address from, address to, address token, uint amount, uint216 amountPerSec) public returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`||
|`to`|`address`|Recipient of the stream|
|`token`|`address`|The token used to fund the stream|
|`amount`|`uint256`|The amount of token funding the stream|
|`amountPerSec`|`uint216`|The amount given to the recipient per second|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The closing balance of the stream|


### deposit

Deposits tokens into a Llamapay pool to provide additional stream funding.


```solidity
function deposit(address from, address token, uint amount) public returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`||
|`token`|`address`|The token used to fund the stream|
|`amount`|`uint256`|The amount of token funding the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The closing balance of the stream|


### withdraw

Withdraws tokens from a Llamapay pool.


```solidity
function withdraw(address to, address token, uint amount) public returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`||
|`token`|`address`|The token used to fund the stream|
|`amount`|`uint256`|The amount of token funding the stream|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The closing balance of the stream|


### _getLlamapayPool

Determines the Llamapay pool based on the token and returns the interface of
the LlamaPay pool for further calls.


```solidity
function _getLlamapayPool(address token) internal view returns (ILlamaPay);
```

