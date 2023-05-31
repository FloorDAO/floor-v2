# ActionMulticall
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/actions/utils/Multicall.sol)

Provides a function to batch together multiple calls in a single external call.


## Functions
### multicall

*Receives and executes a batch of function calls on this contract.*


```solidity
function multicall(address[] calldata actions, bytes[] calldata data) external virtual;
```

