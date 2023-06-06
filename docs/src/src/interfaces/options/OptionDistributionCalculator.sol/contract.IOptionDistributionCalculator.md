# IOptionDistributionCalculator
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/options/OptionDistributionCalculator.sol)

Our {OptionExchange} implements an {IOptionDistributionCalculator} contract to
provide a method of calculating a user's share and discount allocations based
on a seed value.


## Functions
### getShare

Get the share allocation based on the seed.


```solidity
function getShare(uint seed) external virtual returns (uint);
```

### getDiscount

Get the discount allocation based on the seed.


```solidity
function getDiscount(uint seed) external virtual returns (uint);
```

