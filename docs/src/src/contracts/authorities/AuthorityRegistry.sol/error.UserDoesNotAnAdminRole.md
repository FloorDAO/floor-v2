# UserDoesNotAnAdminRole
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/authorities/AuthorityRegistry.sol)

require(hasAdminRole(_msgSender()), 'Only admin roles can grant roles');


```solidity
error UserDoesNotAnAdminRole(address user);
```

