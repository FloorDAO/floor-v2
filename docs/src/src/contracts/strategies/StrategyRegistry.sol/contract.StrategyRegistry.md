# StrategyRegistry
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/strategies/StrategyRegistry.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [IStrategyRegistry](/src/interfaces/strategies/StrategyRegistry.sol/contract.IStrategyRegistry.md)

Allows strategy contracts to be approved and revoked by addresses holding the
{StrategyManager} role. Only once approved can these strategies be applied to
new or existing vaults.
These strategies will be heavily defined in the {IStrategy} interface, but this
Factory focusses solely on managing the list of available vault strategies.


## State Variables
### strategies
Store a mapping of our approved strategies


```solidity
mapping(address => bool) internal strategies;
```


## Functions
### constructor

Set up our {AuthorityControl}.


```solidity
constructor(address _authority) AuthorityControl(_authority);
```

### isApproved

Returns `true` if the contract address is an approved strategy, otherwise
returns `false`.


```solidity
function isApproved(address contractAddr) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddr`|`address`|Address of the contract to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|If the contract has been approved|


### approveStrategy

Approves a strategy contract to be used for vaults. The strategy must hold a defined
implementation and conform to the {IStrategy} interface.
If the strategy is already approved, then no action will be taken.


```solidity
function approveStrategy(address contractAddr) external onlyRole(STRATEGY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddr`|`address`|Strategy to be approved|


### revokeStrategy

Revokes a strategy from being eligible for a vault. This will not affect vaults that
are already instantiated with the strategy.
If the strategy is already approved, then the transaction will be reverted.


```solidity
function revokeStrategy(address contractAddr) external onlyRole(STRATEGY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddr`|`address`|Strategy to be revoked|


