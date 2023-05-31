# UserDoesNotAnAdminRole
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/authorities/AuthorityRegistry.sol)

require(hasAdminRole(_msgSender()), 'Only admin roles can grant roles');


```solidity
error UserDoesNotAnAdminRole(address user);
```

