# ActionMulticall
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/utils/Multicall.sol)

Provides a function to batch together multiple calls in a single external call.


## Functions
### multicall

*Receives and executes a batch of function calls on this contract.*


```solidity
function multicall(address[] calldata actions, bytes[] calldata data) external virtual;
```

