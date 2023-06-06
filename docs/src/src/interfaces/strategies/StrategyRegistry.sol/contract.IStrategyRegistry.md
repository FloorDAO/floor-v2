# IStrategyRegistry
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/strategies/StrategyRegistry.sol)

Allows strategy contracts to be approved and revoked by addresses holding the
{StrategyManager} role. Only once approved can these strategies be applied to
new or existing vaults.
These strategies will be heavily defined in the {IStrategy} interface, but this
Factory focusses solely on managing the list of available vault strategies.


## Functions
### isApproved

Returns `true` if the contract address is an approved strategy, otherwise
returns `false`.


```solidity
function isApproved(address contractAddr) external view returns (bool);
```

### approveStrategy

Approves a strategy contract to be used for vaults. The strategy must hold a defined
implementation and conform to the {IStrategy} interface.


```solidity
function approveStrategy(address contractAddr) external;
```

### revokeStrategy

Revokes a strategy from being eligible for a vault. This will not affect vaults that
are already instantiated with the strategy.


```solidity
function revokeStrategy(address contractAddr) external;
```

## Events
### StrategyApproved
Emitted when a strategy is successfully approved


```solidity
event StrategyApproved(address contractAddr);
```

### StrategyRevoked
Emitted when a strategy has been successfully revoked


```solidity
event StrategyRevoked(address contractAddr);
```

