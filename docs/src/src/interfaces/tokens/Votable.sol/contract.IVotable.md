# IVotable
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/interfaces/tokens/Votable.sol)

**Inherits:**
IERC20


## Functions
### votingPowerOf

*we assume that voting power is a function of balance that preserves order*


```solidity
function votingPowerOf(address account) external view returns (uint);
```

