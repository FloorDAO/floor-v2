# CharmRebalance
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/charmfi/Rebalance.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Updates vault's positions. Can only be called by the strategy keeper.

*Two orders are placed - a base order and a limit order. The base
order is placed first with as much liquidity as possible. This order
should use up all of one token, leaving only the other one. This excess
amount is then placed as a single-sided bid or ask order.*


## Functions
### execute

Calculates new ranges for orders and calls `vault.rebalance()` so that vault can
update its positions.

*Can only be called by keeper.*


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    address strategy;
}
```

