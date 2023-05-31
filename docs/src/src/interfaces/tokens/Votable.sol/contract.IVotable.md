# IVotable
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/tokens/Votable.sol)

**Inherits:**
IERC20


## Functions
### votingPowerOf

*we assume that voting power is a function of balance that preserves order*


```solidity
function votingPowerOf(address account) external view returns (uint);
```

