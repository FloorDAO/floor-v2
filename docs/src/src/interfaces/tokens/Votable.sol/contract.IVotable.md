# IVotable
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/tokens/Votable.sol)

**Inherits:**
IERC20


## Functions
### votingPowerOf

*we assume that voting power is a function of balance that preserves order*


```solidity
function votingPowerOf(address account) external view returns (uint);
```

