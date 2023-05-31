# UnwrapWeth
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/utils/UnwrapWeth.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

This action allows us to unwrap WETH in the {Treasury} into ETH.


## State Variables
### WETH
Mainnet WETH contract


```solidity
address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


## Functions
### execute

Unwraps a fixed amount of WETH into ETH.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|Packed bytes that will map to our `ActionRequest` struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The amount of ETH unwrapped from the WETH by the execution|


### receive

To receive ETH from the WETH's withdraw function (it won't work without it).


```solidity
receive() external payable;
```

## Structs
### ActionRequest
Store our required information to action a swap.


```solidity
struct ActionRequest {
    uint amount;
}
```

