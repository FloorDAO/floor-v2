# ICoWSwapOnchainOrders
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/cowswap/CoWSwapOnchainOrders.sol)

**Author:**
CoW Swap Developers


## Events
### OrderPlacement
*Event emitted to broadcast an order onchain.*


```solidity
event OrderPlacement(address indexed sender, GPv2Order.Data order, OnchainSignature signature, bytes data);
```

## Structs
### OnchainSignature
*Struct containing information on the signign scheme used plus the corresponding signature.*


```solidity
struct OnchainSignature {
    OnchainSigningScheme scheme;
    bytes data;
}
```

## Enums
### OnchainSigningScheme
*List of signature schemes that are supported by this contract to create orders onchain.*


```solidity
enum OnchainSigningScheme {
    Eip1271,
    PreSign
}
```

