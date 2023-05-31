# ActionMulticall
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/utils/Multicall.sol)

Provides a function to batch together multiple calls in a single external call.


## Functions
### multicall

*Receives and executes a batch of function calls on this contract.*


```solidity
function multicall(address[] calldata actions, bytes[] calldata data) external virtual;
```

