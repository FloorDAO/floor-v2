# CannotSetNullAddress
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/utils/Errors.sol)

A collection of generic errors that can be referenced across multiple
contracts. Contract-specific errors should still be stored in their
individual Solidity files.
If a NULL address tries to be stored which should not be accepted


```solidity
error CannotSetNullAddress();
```

