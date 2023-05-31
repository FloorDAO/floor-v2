# GPv2Order
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/cowswap/GPv2Order.sol)

**Author:**
Gnosis Developers


## State Variables
### TYPE_HASH
*The order EIP-712 type hash for the [`GPv2Order.Data`] struct.
This value is pre-computed from the following expression:
```
keccak256(
"Order(" +
"address sellToken," +
"address buyToken," +
"address receiver," +
"uint256 sellAmount," +
"uint256 buyAmount," +
"uint32 validTo," +
"bytes32 appData," +
"uint256 feeAmount," +
"string kind," +
"bool partiallyFillable" +
"string sellTokenBalance" +
"string buyTokenBalance" +
")"
)
```*


```solidity
bytes32 internal constant TYPE_HASH = hex'd5a25ba2e97094ad7d83dc28a6572da797d6b3e7fc6663bd93efb789fc17e489';
```


### KIND_SELL
*The marker value for a sell order for computing the order struct
hash. This allows the EIP-712 compatible wallets to display a
descriptive string for the order kind (instead of 0 or 1).
This value is pre-computed from the following expression:
```
keccak256("sell")
```*


```solidity
bytes32 internal constant KIND_SELL = hex'f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775';
```


### KIND_BUY
*The OrderKind marker value for a buy order for computing the order
struct hash.
This value is pre-computed from the following expression:
```
keccak256("buy")
```*


```solidity
bytes32 internal constant KIND_BUY = hex'6ed88e868af0a1983e3886d5f3e95a2fafbd6c3450bc229e27342283dc429ccc';
```


### BALANCE_ERC20
*The TokenBalance marker value for using direct ERC20 balances for
computing the order struct hash.
This value is pre-computed from the following expression:
```
keccak256("erc20")
```*


```solidity
bytes32 internal constant BALANCE_ERC20 = hex'5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9';
```


### BALANCE_EXTERNAL
*The TokenBalance marker value for using Balancer Vault external
balances (in order to re-use Vault ERC20 approvals) for computing the
order struct hash.
This value is pre-computed from the following expression:
```
keccak256("external")
```*


```solidity
bytes32 internal constant BALANCE_EXTERNAL = hex'abee3b73373acd583a130924aad6dc38cfdc44ba0555ba94ce2ff63980ea0632';
```


### BALANCE_INTERNAL
*The TokenBalance marker value for using Balancer Vault internal
balances for computing the order struct hash.
This value is pre-computed from the following expression:
```
keccak256("internal")
```*


```solidity
bytes32 internal constant BALANCE_INTERNAL = hex'4ac99ace14ee0a5ef932dc609df0943ab7ac16b7583634612f8dc35a4289a6ce';
```


### RECEIVER_SAME_AS_OWNER
*Marker address used to indicate that the receiver of the trade
proceeds should the owner of the order.
This is chosen to be `address(0)` for gas efficiency as it is expected
to be the most common case.*


```solidity
address internal constant RECEIVER_SAME_AS_OWNER = address(0);
```


### UID_LENGTH
*The byte length of an order unique identifier.*


```solidity
uint internal constant UID_LENGTH = 56;
```


## Functions
### actualReceiver

*Returns the actual receiver for an order. This function checks
whether or not the [`receiver`] field uses the marker value to indicate
it is the same as the order owner.*


```solidity
function actualReceiver(Data memory order, address owner) internal pure returns (address receiver);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The actual receiver of trade proceeds.|


### hash

*Return the EIP-712 signing hash for the specified order.*


```solidity
function hash(Data memory order, bytes32 domainSeparator) internal pure returns (bytes32 orderDigest);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`order`|`Data`|The order to compute the EIP-712 signing hash for.|
|`domainSeparator`|`bytes32`|The EIP-712 domain separator to use.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`orderDigest`|`bytes32`|The 32 byte EIP-712 struct hash.|


### packOrderUidParams

*Packs order UID parameters into the specified memory location. The
result is equivalent to `abi.encodePacked(...)` with the difference that
it allows re-using the memory for packing the order UID.
This function reverts if the order UID buffer is not the correct size.*


```solidity
function packOrderUidParams(bytes memory orderUid, bytes32 orderDigest, address owner, uint32 validTo) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`orderUid`|`bytes`|The buffer pack the order UID parameters into.|
|`orderDigest`|`bytes32`|The EIP-712 struct digest derived from the order parameters.|
|`owner`|`address`|The address of the user who owns this order.|
|`validTo`|`uint32`|The epoch time at which the order will stop being valid.|


### extractOrderUidParams

*Extracts specific order information from the standardized unique
order id of the protocol.*


```solidity
function extractOrderUidParams(bytes calldata orderUid) internal pure returns (bytes32 orderDigest, address owner, uint32 validTo);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`orderUid`|`bytes`|The unique identifier used to represent an order in the protocol. This uid is the packed concatenation of the order digest, the validTo order parameter and the address of the user who created the order. It is used by the user to interface with the contract directly, and not by calls that are triggered by the solvers.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`orderDigest`|`bytes32`|The EIP-712 signing digest derived from the order parameters.|
|`owner`|`address`|The address of the user who owns this order.|
|`validTo`|`uint32`|The epoch time at which the order will stop being valid.|


## Structs
### Data
*The complete data for a Gnosis Protocol order. This struct contains
all order parameters that are signed for submitting to GP.*


```solidity
struct Data {
    IERC20 sellToken;
    IERC20 buyToken;
    address receiver;
    uint sellAmount;
    uint buyAmount;
    uint32 validTo;
    bytes32 appData;
    uint feeAmount;
    bytes32 kind;
    bool partiallyFillable;
    bytes32 sellTokenBalance;
    bytes32 buyTokenBalance;
}
```

