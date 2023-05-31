# CowSwapCreateOrder
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/cowswap/CreateOrder.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md), [ICoWSwapOnchainOrders](/src/interfaces/cowswap/CoWSwapOnchainOrders.sol/contract.ICoWSwapOnchainOrders.md)

Interacts with the CowSwap protocol to create an order.
Based on codebase:
https://github.com/nlordell/dappcon-2022-smart-orders


## State Variables
### APP_DATA
Encoded app data to recognise our transactions


```solidity
bytes32 public constant APP_DATA = keccak256('floordao');
```


### settlement
Stores the external {CowSwapSettlement} contract reference

*Mainnet implementation: 0x9008d19f58aabd9ed0d60971565aa8510560ab41*


```solidity
ICoWSwapSettlement public immutable settlement;
```


### domainSeparator
Domain separator taked from the settlement contract


```solidity
bytes32 public immutable domainSeparator;
```


### weth
Constant address of the WETH token


```solidity
address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


## Functions
### constructor

Sets up our {CowSwapSettlement} contract reference


```solidity
constructor(address settlement_);
```

### execute


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest
*The complete data for a Gnosis Protocol order. This struct contains
all order parameters that are signed for submitting to GP.*


```solidity
struct ActionRequest {
    address sellToken;
    address buyToken;
    address receiver;
    uint sellAmount;
    uint buyAmount;
    uint feeAmount;
}
```

