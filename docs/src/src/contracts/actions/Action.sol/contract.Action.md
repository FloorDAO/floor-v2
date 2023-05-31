# Action
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/Action.sol)

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


