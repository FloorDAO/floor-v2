# CannotSetNullAddress
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/utils/Errors.sol)

A collection of generic errors that can be referenced across multiple
contracts. Contract-specific errors should still be stored in their
individual Solidity files.
If a NULL address tries to be stored which should not be accepted


```solidity
error CannotSetNullAddress();
```

