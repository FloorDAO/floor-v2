# SafeMathInt
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/utils/SafeMathInt.sol)

*Math operations with safety checks that revert on error*

*SafeMath adapted for int256
Based on code of  https://github.com/RequestNetwork/requestNetwork/blob/master/packages/requestNetworkSmartContracts/contracts/base/math/SafeMathInt.sol*


## Functions
### mul


```solidity
function mul(int a, int b) internal pure returns (int);
```

### div


```solidity
function div(int a, int b) internal pure returns (int);
```

### sub


```solidity
function sub(int a, int b) internal pure returns (int);
```

### add


```solidity
function add(int a, int b) internal pure returns (int);
```

### toUint256Safe


```solidity
function toUint256Safe(int a) internal pure returns (uint);
```

