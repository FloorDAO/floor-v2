# NftStakingBoostCalculator
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/staking/calculators/NftStakingBoostCalculator.sol)

**Inherits:**
[INftStakingBoostCalculator](/src/interfaces/staking/calculators/NftStakingBoostCalculator.sol/contract.INftStakingBoostCalculator.md)

Calculates the boost power generated from staked NFTs, factoring in the total
number of NFTs staked to give declining power when more tokens are staked.
The formula for this is documented against the `calculate` function.


## Functions
### calculate

Performs the calculation to return the boost amount generated by the
staked tokens.
In Excel / Sheets terms, this formula roughly equates to:
```
(LOG(sweepPower, sweepTotal) * (SQRT(sweepTotal) - 1)) / sweepModifier
```

*If a value of uint56 is passed, then we may get overflow results*


```solidity
function calculate(uint sweepPower, uint sweepTotal, uint sweepModifier) external pure returns (uint boost_);
```

