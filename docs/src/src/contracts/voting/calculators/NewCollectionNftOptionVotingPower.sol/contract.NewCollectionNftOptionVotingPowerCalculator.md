# NewCollectionNftOptionVotingPowerCalculator
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/voting/calculators/NewCollectionNftOptionVotingPower.sol)

**Inherits:**
[INftVotingPowerCalculator](/src/contracts/voting/calculators/NewCollectionNftOptionVotingPower.sol/contract.INftVotingPowerCalculator.md)

Calculates the voting power applied from a created option, factoring in the spot
price and exercise percentage.
The formula for this is documented against the `calculate` function.


## Functions
### calculate

Performs the calculation to return the vote power given from an
exercisable option.


```solidity
function calculate(uint, address, uint spotPrice, uint exercisePercent) external pure returns (uint);
```

