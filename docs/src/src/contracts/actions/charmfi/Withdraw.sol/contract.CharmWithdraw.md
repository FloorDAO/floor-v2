# CharmWithdraw
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/charmfi/Withdraw.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Withdraws tokens in proportion to the vault's holdings.


## Functions
### execute


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    uint shares;
    uint amount0Min;
    uint amount1Min;
    address vault;
}
```

