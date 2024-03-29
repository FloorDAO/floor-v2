# WrapEth
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/utils/WrapEth.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

This action allows us to wrap ETH in the {Treasury} into WETH.


## State Variables
### WETH
Mainnet WETH contract


```solidity
address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


## Functions
### execute

Wraps a fixed amount of ETH into WETH.


```solidity
function execute(bytes calldata) public payable override whenNotPaused returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The amount of ETH wrapped into WETH by the execution|


