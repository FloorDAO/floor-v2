# Action
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/Action.sol)

**Inherits:**
[IAction](/src/interfaces/actions/Action.sol/contract.IAction.md), Ownable, Pausable

Handles our core action logic that each action should inherit.


## Functions
### execute

Stores the executed code for the action.


```solidity
function execute(bytes calldata) public payable virtual whenNotPaused returns (uint);
```

### pause

Pauses execution functionality.


```solidity
function pause(bool _p) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_p`|`bool`|Boolean value for if the vault should be paused|


