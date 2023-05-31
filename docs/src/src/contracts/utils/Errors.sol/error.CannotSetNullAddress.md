# CannotSetNullAddress
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/utils/Errors.sol)

A collection of generic errors that can be referenced across multiple
contracts. Contract-specific errors should still be stored in their
individual Solidity files.
If a NULL address tries to be stored which should not be accepted


```solidity
error CannotSetNullAddress();
```

