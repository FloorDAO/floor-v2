# CannotSetNullAddress
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/utils/Errors.sol)

A collection of generic errors that can be referenced across multiple
contracts. Contract-specific errors should still be stored in their
individual Solidity files.
If a NULL address tries to be stored which should not be accepted


```solidity
error CannotSetNullAddress();
```

