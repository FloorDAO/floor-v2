# ActionMulticall
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/utils/Multicall.sol)

Provides a function to batch together multiple calls in a single external call.


## Functions
### multicall

*Receives and executes a batch of function calls on this contract.*


```solidity
function multicall(address[] calldata actions, bytes[] calldata data) external virtual;
```

