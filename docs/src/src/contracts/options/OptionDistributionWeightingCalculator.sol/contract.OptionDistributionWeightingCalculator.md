# OptionDistributionWeightingCalculator
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/options/OptionDistributionWeightingCalculator.sol)

**Inherits:**
[IOptionDistributionCalculator](/src/interfaces/options/OptionDistributionCalculator.sol/contract.IOptionDistributionCalculator.md)

Our Weighting calculator allows us to set a predefined ladder of weights that
map to an allocation amount. This allows us to set a gas optimised method of
allocation traversal.


## State Variables
### sum
Stores the total value of all weightings. We use this to
offset our seed to be within an expected range.


```solidity
uint public immutable sum;
```


### length
Stores the length of our weights array to save gas in loops


```solidity
uint public immutable length;
```


### weights
Stores our allocation : weight array


```solidity
uint[] public weights;
```


## Functions
### constructor

Accepts a bytes-encoded array of unsigned integers. We then store static
calculations to reduce gas on future calls.


```solidity
constructor(bytes memory initData);
```

### getShare

Get the share allocation based on the seed. If we generate a 0 share then we
set it to 1 as a minimum threshold.


```solidity
function getShare(uint seed) external virtual override returns (uint share);
```

### getDiscount

Get the discount allocation based on the seed.


```solidity
function getDiscount(uint seed) external virtual override returns (uint);
```

### _get

We use our seed to find where our seed falls in the weighted ladder. The
key of our weights array maps to the allocation granted, whilst the value


```solidity
function _get(uint seed) internal view returns (uint i);
```

