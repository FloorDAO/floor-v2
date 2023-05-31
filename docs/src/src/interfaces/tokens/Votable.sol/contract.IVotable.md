# IVotable
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/tokens/Votable.sol)

**Inherits:**
IERC20


## Functions
### votingPowerOf

*we assume that voting power is a function of balance that preserves order*


```solidity
function votingPowerOf(address account) external view returns (uint);
```

