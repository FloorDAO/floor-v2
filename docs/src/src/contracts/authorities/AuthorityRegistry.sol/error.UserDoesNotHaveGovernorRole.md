# UserDoesNotHaveGovernorRole
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/authorities/AuthorityRegistry.sol)

require(_roles[GOVERNOR][_msgSender()]);


```solidity
error UserDoesNotHaveGovernorRole(address user);
```

